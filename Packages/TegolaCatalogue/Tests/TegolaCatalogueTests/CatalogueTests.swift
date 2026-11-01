import Foundation
import Testing

@testable import TegolaCatalogue

@Suite struct CatalogueTests {
  /// PLAN §2.9 F1 (first half; subtypes and signatures join in M2).
  @Test func everyManifestDecodesAndValidates() throws {
    let catalogue = try Catalogue.bundled()
    #expect(catalogue.manifests.count == 18)
    #expect(catalogue.problems.isEmpty, "\(catalogue.problems)")
  }

  /// PLAN §2.9 F1, D-23.
  @Test func v1TypesAreTheFourEnabled() throws {
    let catalogue = try Catalogue.bundled()
    #expect(catalogue.enabled.map(\.id) == ["music", "video-game", "board-games", "thing"])
  }

  @Test func idsAreUnique() throws {
    let ids = try Catalogue.bundled().manifests.map(\.id)
    #expect(Set(ids).count == ids.count)
  }

  @Test func musicReadsAsTheTypeFileSaysItShould() throws {
    let music = try #require(try Catalogue.bundled().manifest("music"))
    #expect(music.name.collection == "My Music")
    #expect(music.name.singular == "Release")
    #expect(music.duplicates == .rows)
    #expect(music.spine.title == "Album")
    #expect(music.spine.subtitle == "Artist")
    #expect(music.conditions.first == "Mint")
    let vinyl = try #require(music.subtypes.first { $0.key == "vinyl" })
    #expect(vinyl.adds.first { $0.key == "rpm" }?.options == ["33⅓", "45", "78"])
  }

  /// D-18: subtypes replace the per-medium tables, so no file has one and every file with a medium has subtypes.
  @Test func mediumTablesBecameSubtypes() throws {
    let catalogue = try Catalogue.bundled()
    #expect(catalogue.manifest("video-game")?.subtypes.map(\.key) == ["saturn", "n64", "neo-geo", "game-boy", "ps1"])
    #expect(catalogue.manifest("music")?.subtypes.map(\.key) == ["vinyl", "cd", "cassette", "other"])
    #expect(catalogue.manifest("vehicles")?.subtypes.map(\.key) == ["car", "motorbike"])
    let games = try #require(catalogue.manifest("video-game"))
    #expect(games.fields.contains { $0.key == "playStatus" })
    let saturn = try #require(games.subtypes.first)
    #expect(saturn.presets["media"] == .value("Optical disc"))
    #expect(saturn.presets["region"] == .options(["NTSC-J", "NTSC-U", "PAL"]))
    #expect(saturn.parts == ["case", "manual", "disc", "spine card"])
    #expect(saturn.clocks == ["discRot-pending"])
  }

  @Test func videoMediaHasItsEightSubtypes() throws {
    let media = try #require(try Catalogue.bundled().manifest("video-media"))
    #expect(media.subtypes.map(\.key) == ["vhs", "betamax", "laserdisc", "ced", "dvd", "hd-dvd", "blu-ray", "uhd"])
    #expect(media.subtypes.allSatisfy { $0.presets["packaging"] != nil })
  }

  @Test func videoMediaPresetsReadAsHiddenValuesOptionsPartsAndClocks() throws {
    let media = try #require(try Catalogue.bundled().manifest("video-media"))
    let vhs = try #require(media.subtypes.first { $0.key == "vhs" })
    #expect(vhs.label == "VHS")
    #expect(vhs.presets["regionCode"] == .hidden)
    #expect(vhs.presets["packaging"] == .options(["slipcase", "clamshell", "big box"]))
    #expect(vhs.parts == ["sleeve", "shell", "tape", "insert"])
    #expect(vhs.clocks == ["mediaRot"])
    #expect(vhs.adds.map(\.key) == ["tapeSpeed", "printMark"])
    let bluRay = try #require(media.subtypes.first { $0.key == "blu-ray" })
    #expect(bluRay.lookup == ["barcode", "spineNo"])
    #expect(bluRay.presets["regionCode"] == .options(["A", "B", "C", "free"]))
  }

  @Test func signaturesLookupAndSupersessionDecode() throws {
    let games = try #require(try Catalogue.bundled().manifest("video-game"))
    #expect(games.signatures.map(\.renderer) == ["ladder", "set"])
    #expect(games.signatures[0].axes == ["mediaCondition", "boxCondition", "manualCondition"])
    #expect(games.signatures[1].binds == "inserts")
    #expect(games.lookup?.identifier == nil)
    #expect(games.lookup?.identifierPattern == "per-platform")
    #expect(games.supersedes.first?.fields["cib"] == "derived")
    #expect(games.allowMissing)
    let music = try #require(try Catalogue.bundled().manifest("music"))
    #expect(music.supersedes.first?.sets == ["medium": "Vinyl"])
    #expect(try Catalogue.bundled().manifest("wine")?.isConsumable == true)
    #expect(try Catalogue.bundled().manifest("thing")?.allowsOwnFields == true)
  }

  @Test func aScalarPresetFillsAndHides() throws {
    let yaml =
      ValidationTests.base
      + "\nconditions: [Good, Bad]\nfields:\n  - {key: media, label: Media, type: choice, options: [Disc, Cart]}"
      + "\nsubtypes:\n  - {key: a, label: A, presets: {media: Disc, clock: none}}"
    let subtype = try #require(try ValidationTests.manifest(yaml).subtypes.first)
    #expect(subtype.presets["media"] == .value("Disc"))
    #expect(subtype.clocks.isEmpty)
  }

  @Test func thingAsksAboutDuplicates() throws {
    #expect(try Catalogue.bundled().manifest("thing")?.duplicates == .ask)
  }
}

@Suite struct ValidationTests {
  static func manifest(_ yaml: String) throws -> TypeManifest {
    try Catalogue.decode(Data(yaml.utf8), file: "test.yml")
  }

  static let base = """
    id: sample
    name: {singular: Sample, plural: Samples, collection: My Samples}
    mark: S
    icon: square
    duplicates: rows
    spine: {title: Title}
    """

  @Test func unknownFieldKindIsAnError() {
    let yaml = Self.base + "\nconditions: [Good, Bad]\nfields:\n  - {key: a, label: A, type: colour}"
    #expect(throws: CatalogueError.self) { try Self.manifest(yaml) }
  }

  @Test func aliasesMapToTheirKind() throws {
    let yaml =
      Self.base
      + "\nconditions: [Good, Bad]\nfields:\n  - {key: a, label: A, type: int}\n  - {key: b, label: B, type: bool}"
    #expect(try Self.manifest(yaml).fields.map(\.kind) == [.number, .yesNo])
  }

  @Test func aMisspelledKeyIsAnError() {
    #expect(throws: CatalogueError.self) {
      try Self.manifest(
        Self.base + "\nconditions: [Good, Bad]\nfields:\n  - {key: a, label: A, type: text, requried: true}"
      )
    }
    #expect(throws: CatalogueError.self) {
      try Self.manifest(Self.base + "\nconditions: [Good, Bad]\nfeilds: []\nfields: []")
    }
  }

  @Test func malformedPresetsAreAnErrorNotAnEmptySet() {
    let yaml = Self.base + "\nconditions: [Good, Bad]\nfields: []\nsubtypes:\n  - {key: a, label: A, presets: [shape]}"
    #expect(throws: CatalogueError.self) { try Self.manifest(yaml) }
  }

  @Test(arguments: ["Sample", "café", "-sample", "sam--ple", "sample-"])
  func idsMustBeKebabCaseASCII(_ id: String) throws {
    let yaml =
      Self.base.replacingOccurrences(of: "id: sample", with: "id: \"\(id)\"") + "\nconditions: [Good, Bad]\nfields: []"
    #expect(try Self.manifest(yaml).problems.count == 1)
  }

  @Test func missingMustComeLast() throws {
    let yaml = Self.base + "\nconditions: [Good, Missing, Bad]\nfields: []"
    #expect(try Self.manifest(yaml).problems.map(\.message) == ["\"Missing\" must be the last condition step (PD-014)"])
  }

  @Test func aChoiceWithoutOptionsNeedsEverySubtypeToPresetIt() throws {
    let field = "\nconditions: [Good, Bad]\nfields:\n  - {key: shape, label: Shape, type: choice}"
    #expect(try Self.manifest(Self.base + field).problems.count == 1)
    let presetByAll =
      field + "\nsubtypes:\n  - {key: a, label: A, presets: {shape: [round]}}"
      + "\n  - {key: b, label: B, presets: {shape: [square]}}"
    #expect(try Self.manifest(Self.base + presetByAll).problems.isEmpty)
    let presetBySome = field + "\nsubtypes:\n  - {key: a, label: A, presets: {shape: [round]}}\n  - {key: b, label: B}"
    #expect(try Self.manifest(Self.base + presetBySome).problems.count == 1)
  }

  @Test func duplicateFieldKeysAreReported() throws {
    let yaml =
      Self.base
      + "\nconditions: [Good, Bad]\nfields:\n  - {key: a, label: A, type: text}\n  - {key: a, label: B, type: text}"
    #expect(try Self.manifest(yaml).problems.map(\.message) == ["field key \"a\" appears more than once"])
  }
}

import Foundation
import Testing

@testable import TegolaCatalogue

/// M2's exit test (page 52, P0): loading `video-game.yml` and `video-media.yml` gives the right field lists for all 13
/// subtypes. Each list is written out, so a change to a type file shows up here as a diff a reviewer reads.
@Suite struct ResolverTests {
  static let catalogue = Result { try Catalogue.bundled() }

  static func resolve(_ type: TypeManifest.ID, _ subtype: String?) throws -> EffectiveType {
    let manifest = try #require(try catalogue.get().manifest(type))
    return try manifest.resolve(subtype: subtype)
  }

  static let gameParent = [
    "publisher", "catalogueNumber", "region", "edition", "revision", "mediaCondition", "boxCondition",
    "manualCondition", "inserts", "slab", "saveBattery", "codeExpires", "playStatus", "playLog",
  ]
  static let mediaParent = [
    "director", "studio", "label", "edition", "cut", "standard", "regionCode", "aspect", "discs", "packaging",
    "slipcover", "spineNo", "exRental", "mediaCondition", "caseCondition", "sleeveCondition", "inserts", "watchLog",
  ]

  struct Expected: Sendable, CustomTestStringConvertible {
    let type: TypeManifest.ID
    let subtype: String
    /// The fields a collector sees, in order.
    let visible: [String]
    /// Hidden fields and the value a preset fills in (nil: hidden, not filled).
    let hidden: [String: String?]
    let clocks: [String]
    let ladder: [String]

    var testDescription: String { "\(type.rawValue)/\(subtype)" }
  }

  static func parent(_ list: [String], without: Set<String> = [], replacing: [String: String] = [:]) -> [String] {
    list.filter { !without.contains($0) }.map { replacing[$0] ?? $0 }
  }

  static let expected: [Expected] = [
    Expected(
      type: "video-game",
      subtype: "saturn",
      visible: gameParent + ["spineCard", "ramCart", "satakore"],
      hidden: ["platform": "Sega Saturn", "media": "Optical disc"],
      clocks: ["codeExpiry", "unfinished", "discRot-pending"],
      ladder: ["mediaCondition", "boxCondition", "manualCondition"]
    ),
    Expected(
      type: "video-game",
      subtype: "n64",
      visible: gameParent + ["expansionPak", "pakSupport"],
      hidden: ["platform": "Nintendo 64", "media": "Cartridge"],
      clocks: ["codeExpiry", "unfinished", "saveBattery"],
      ladder: ["mediaCondition", "boxCondition", "manualCondition"]
    ),
    Expected(
      type: "video-game",
      subtype: "neo-geo",
      visible: gameParent + ["board", "conversion"],
      hidden: ["platform": "Neo Geo", "media": "Cartridge"],
      clocks: ["codeExpiry", "unfinished"],
      ladder: ["mediaCondition", "boxCondition", "manualCondition"]
    ),
    Expected(
      type: "video-game",
      subtype: "game-boy",
      visible: gameParent + ["sgb"],
      hidden: ["platform": "Game Boy", "media": "Cartridge"],
      clocks: ["codeExpiry", "unfinished", "saveBattery"],
      ladder: ["mediaCondition", "boxCondition", "manualCondition"]
    ),
    Expected(
      type: "video-game",
      subtype: "ps1",
      visible: gameParent + ["printLabel"],
      hidden: ["platform": "PlayStation", "media": "Optical disc"],
      clocks: ["codeExpiry", "unfinished", "discRot-pending"],
      ladder: ["mediaCondition", "boxCondition", "manualCondition"]
    ),
    Expected(
      type: "video-media",
      subtype: "vhs",
      visible: parent(mediaParent, without: ["regionCode"]) + ["tapeSpeed", "printMark"],
      hidden: ["regionCode": nil],
      clocks: ["mediaRot"],
      ladder: ["mediaCondition", "caseCondition", "sleeveCondition"]
    ),
    Expected(
      type: "video-media",
      subtype: "betamax",
      visible: parent(mediaParent, without: ["regionCode"]) + ["tapeSpeed", "betaHifi"],
      hidden: ["regionCode": nil],
      clocks: ["mediaRot"],
      ladder: ["mediaCondition", "caseCondition", "sleeveCondition"]
    ),
    Expected(
      type: "video-media",
      subtype: "laserdisc",
      visible: parent(mediaParent, without: ["regionCode"]) + ["sides", "encoding", "obi"],
      hidden: ["regionCode": nil],
      clocks: ["discRot"],
      ladder: ["mediaCondition", "caseCondition", "sleeveCondition"]
    ),
    Expected(
      type: "video-media",
      subtype: "ced",
      visible: parent(mediaParent, without: ["regionCode"], replacing: ["caseCondition": "caddyCondition"]),
      hidden: ["regionCode": nil, "caseCondition": nil],
      clocks: ["mediaRot"],
      ladder: ["mediaCondition", "caddyCondition", "sleeveCondition"]
    ),
    Expected(
      type: "video-media",
      subtype: "dvd",
      visible: mediaParent + ["layers"],
      hidden: [:],
      clocks: ["discRot"],
      ladder: ["mediaCondition", "caseCondition", "sleeveCondition"]
    ),
    Expected(
      type: "video-media",
      subtype: "hd-dvd",
      visible: parent(mediaParent, without: ["regionCode"]) + ["combo"],
      hidden: ["regionCode": nil],
      clocks: ["discRot-pending"],
      ladder: ["mediaCondition", "caseCondition", "sleeveCondition"]
    ),
    Expected(
      type: "video-media",
      subtype: "blu-ray",
      visible: mediaParent + ["limitedNo"],
      hidden: [:],
      clocks: ["discRot"],
      ladder: ["mediaCondition", "caseCondition", "sleeveCondition"]
    ),
    Expected(
      type: "video-media",
      subtype: "uhd",
      visible: parent(mediaParent, without: ["regionCode"]) + ["hdr", "bdIncluded"],
      hidden: ["regionCode": nil],
      clocks: ["discRot-pending"],
      ladder: ["mediaCondition", "caseCondition", "sleeveCondition"]
    ),
  ]

  @Test func thirteenSubtypes() throws {
    let games = try #require(try Self.catalogue.get().manifest("video-game"))
    let media = try #require(try Self.catalogue.get().manifest("video-media"))
    #expect(games.subtypes.count + media.subtypes.count == 13)
    #expect(Set(Self.expected.map(\.testDescription)).count == 13)
  }

  @Test(arguments: expected)
  func subtypeResolvesToItsFieldList(_ expected: Expected) throws {
    let effective = try Self.resolve(expected.type, expected.subtype)
    #expect(effective.visibleFields.map(\.key) == expected.visible)
    let hidden = Dictionary(uniqueKeysWithValues: effective.fields.filter(\.isHidden).map { ($0.key, $0.presetValue) })
    #expect(hidden == expected.hidden)
    #expect(effective.clocks == expected.clocks.map(ClockReference.init))
    #expect(effective.signatures.first?.axes == expected.ladder)
  }

  @Test func narrowedChoicesOfferOnlyTheSubtypesOptions() throws {
    #expect(try Self.resolve("video-game", "saturn").field("region")?.field.options == ["NTSC-J", "NTSC-U", "PAL"])
    #expect(try Self.resolve("video-game", "n64").field("region")?.field.options.count == 4)
    #expect(try Self.resolve("video-media", "blu-ray").field("regionCode")?.field.options == ["A", "B", "C", "free"])
    #expect(try Self.resolve("video-media", "ced").field("packaging")?.field.options == ["caddy"])
  }

  @Test func theSetCountsTheSubtypesPartsOrTheParentsSlots() throws {
    #expect(
      try Self.resolve("video-game", "n64").field("inserts")?.field.options
        == ["box", "manual", "cart", "dust cover", "insert"]
    )
    #expect(try Self.resolve("video-game", nil).field("inserts")?.field.options == ["manual", "insert"])
    #expect(
      try Self.resolve("video-media", "dvd").field("inserts")?.field.options == ["case", "disc", "booklet", "insert"]
    )
  }

  @Test func origins() throws {
    let saturn = try Self.resolve("video-game", "saturn")
    #expect(saturn.field("region")?.origin == .type)
    #expect(saturn.field("spineCard")?.origin == .subtype)
  }

  @Test func lookupComesFromTheSubtypeOrTheType() throws {
    #expect(try Self.resolve("video-game", "ps1").lookup == ["catalogueNumber", "barcode"])
    #expect(try Self.resolve("video-game", nil).lookup == [])
    #expect(try Self.resolve("music", nil).lookup == ["barcode"])
  }

  @Test func theParentAloneHasEveryFieldVisible() throws {
    let games = try #require(try Self.catalogue.get().manifest("video-game"))
    let effective = try games.resolve(subtype: nil)
    #expect(effective.visibleFields.map(\.key) == games.fields.map(\.key))
    #expect(effective.clocks.map(\.name) == ["codeExpiry", "unfinished"])
  }

  @Test func anUnknownSubtypeIsAnError() throws {
    let games = try #require(try Self.catalogue.get().manifest("video-game"))
    #expect(throws: ResolveError.unknownSubtype(type: "video-game", subtype: "dreamcast")) {
      try games.resolve(subtype: "dreamcast")
    }
  }

  @Test func musicFormatsAreNarrowedPerSubtype() throws {
    #expect(try Self.resolve("music", "cassette").field("format")?.field.options.first == "Cassette")
    #expect(try Self.resolve("music", "vinyl").field("medium")?.presetValue == "Vinyl")
    #expect(try Self.resolve("music", "vinyl").field("medium")?.isHidden == true)
  }
}

/// Page 48's rules, one broken at a time.
@Suite struct SubtypeRuleTests {
  static let parent =
    ValidationTests.base + """

      conditions: [Good, Bad]
      signatures:
        - {renderer: ladder, axes: [box]}
        - {renderer: set, binds: parts}
      fields:
        - {key: media, label: Media, type: choice, options: [Disc, Cart]}
        - {key: box, label: Box, type: scale}
        - {key: parts, label: Parts, type: set, options: [box], slotsFrom: subtype}
      subtypes:
      """

  static func problems(_ subtype: String) throws -> [String] {
    try ValidationTests.manifest(parent + "\n  - " + subtype).problems.map(\.message)
  }

  @Test func aValidSubtypeHasNoProblems() throws {
    let subtype =
      "{key: a, label: A, presets: {media: Disc, parts: [box, disc]}, adds: [{key: x, label: X, type: text}]}"
    #expect(try Self.problems(subtype).isEmpty)
  }

  @Test func anAdditionCantRedefineAParentField() throws {
    #expect(try Self.problems("{key: a, label: A, adds: [{key: media, label: M, type: text}]}").count == 1)
  }

  @Test func aPresetMustNameAParentField() throws {
    #expect(try Self.problems("{key: a, label: A, presets: {colour: red}}").count == 1)
  }

  @Test func aPresetValueMustBeAnOption() throws {
    #expect(try Self.problems("{key: a, label: A, presets: {media: Tape}}").count == 1)
  }

  @Test func narrowingCanOnlyRemoveOptions() throws {
    #expect(try Self.problems("{key: a, label: A, presets: {media: [Disc, Tape]}}").count == 1)
    #expect(try Self.problems("{key: a, label: A, presets: {media: [Disc]}}").isEmpty)
  }

  @Test func onlyAChoiceCanBeNarrowed() throws {
    #expect(try Self.problems("{key: a, label: A, presets: {box: [Good]}}").count == 1)
  }

  @Test func aReplacementMustNameAParentFieldOfTheSameKind() throws {
    #expect(try Self.problems("{key: a, label: A, adds: [{key: caddy, label: C, type: scale, replaces: box}]}").isEmpty)
    #expect(
      try Self.problems("{key: a, label: A, adds: [{key: caddy, label: C, type: text, replaces: box}]}").count == 1
    )
    #expect(
      try Self.problems("{key: a, label: A, adds: [{key: caddy, label: C, type: scale, replaces: lid}]}").count == 1
    )
  }

  @Test func subtypeKeysAreUnique() throws {
    #expect(try Self.problems("{key: a, label: A}\n  - {key: a, label: B}").count == 1)
  }

  @Test func partsNeedASetSignature() throws {
    let yaml =
      ValidationTests.base
      + "\nconditions: [Good, Bad]\nfields: []\nsubtypes:\n  - {key: a, label: A, presets: {parts: [box]}}"
    #expect(try ValidationTests.manifest(yaml).problems.count == 1)
  }

  @Test func ladderAxesAreScaleFields() throws {
    let yaml =
      ValidationTests.base
      + "\nconditions: [Good, Bad]\nsignatures: [{renderer: ladder, axes: [box]}]\n"
      + "fields: [{key: box, label: Box, type: text}]"
    #expect(try ValidationTests.manifest(yaml).problems.count == 1)
  }

  @Test func aSetWithNoSlotsNeedsPartsFromEverySubtype() throws {
    let yaml =
      ValidationTests.base
      + "\nconditions: [Good, Bad]\nsignatures: [{renderer: set, binds: parts}]\n"
      + "fields: [{key: parts, label: Parts, type: set, slotsFrom: subtype}]\n"
      + "subtypes:\n  - {key: a, label: A, presets: {parts: [box]}}\n  - {key: b, label: B}"
    #expect(try ValidationTests.manifest(yaml).problems.count == 1)
  }

  @Test func aLargeSubtypeIsFlaggedNotBlocked() throws {
    let adds = (1...6).map { "{key: f\($0), label: F, type: text}" }.joined(separator: ", ")
    let manifest = try ValidationTests.manifest(Self.parent + "\n  - {key: big, label: Big, adds: [\(adds)]}")
    #expect(manifest.problems.isEmpty)
    #expect(manifest.subtypesForReview == ["big"])
  }
}

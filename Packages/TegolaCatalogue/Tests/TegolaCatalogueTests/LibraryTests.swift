import Foundation
import Testing

@testable import TegolaCatalogue

/// The item level, the clock library and the signature kit (PLAN §3.3, page 48, page 52).
@Suite struct LibraryTests {
  @Test func theItemLevelHasSignedAndBundleOf() throws {
    let item = try Catalogue.bundled().item
    #expect(item.fields.map(\.key) == ["signed", "contains", "bundleSealed"])
    #expect(item.fields.first?.entry == ["by", "dedication", "date", "proof"])
  }

  @Test func everyTypeInheritsTheItemLevelHiddenUntilAdded() throws {
    let catalogue = try Catalogue.bundled()
    for manifest in catalogue.manifests {
      let effective = try catalogue.resolve(manifest.id, subtype: nil)
      #expect(effective.addableFields.map(\.key) == ["signed", "contains", "bundleSealed"], "\(manifest.id.rawValue)")
      #expect(!effective.visibleFields.contains { $0.origin == .item })
    }
    let saturn = try catalogue.resolve("video-game", subtype: "saturn")
    #expect(saturn.fields.suffix(3).map(\.origin) == [.item, .item, .item])
  }

  @Test func aTypeFieldCantTakeAnItemLevelKey() throws {
    let manifest = try ValidationTests.manifest(
      ValidationTests.base + "\nconditions: [Good, Bad]\nfields: [{key: signed, label: Signed, type: yesNo}]"
    )
    let catalogue = Catalogue(manifests: [manifest], item: try Catalogue.bundled().item)
    #expect(catalogue.problems.map(\.message) == ["field \"signed\" is an item-level field"])
  }

  @Test func unknownTypeIsAnError() throws {
    #expect(throws: ResolveError.unknownType("dreamcast")) {
      try Catalogue.bundled().resolve("dreamcast", subtype: nil)
    }
  }

  @Test func everyClockATypeNamesIsInTheLibrary() throws {
    let catalogue = try Catalogue.bundled()
    let named = catalogue.manifests.flatMap { $0.clocks + $0.subtypes.flatMap(\.clocks) }
    #expect(!named.isEmpty)
    for name in named {
      #expect(ClockReference(name).definition != nil, "\(name)")
    }
  }

  @Test func aPendingClockIsTheSameClockHeldBack() {
    let pending = ClockReference("discRot-pending")
    #expect(pending.name == "discRot")
    #expect(pending.isPending)
    #expect(pending.definition?.name == "discRot")
    #expect(!ClockReference("discRot").isPending)
  }

  @Test func libraryNamesAreUnique() {
    let names = ClockLibrary.all.map(\.name)
    #expect(Set(names).count == names.count)
  }

  @Test func aTypeCantDefineItsOwnClock() throws {
    let yaml = ValidationTests.base + "\nconditions: [Good, Bad]\nclocks: [moonPhase]\nfields: []"
    #expect(
      try ValidationTests.manifest(yaml).problems.map(\.message)
        == ["clock \"moonPhase\" isn't in the app's library: a type can't define its own"]
    )
  }

  @Test func aTypeCantInventARenderer() throws {
    let yaml =
      ValidationTests.base
      + "\nconditions: [Good, Bad]\nsignatures: [{renderer: sparkline, binds: a}]\nfields: [{key: a, label: A, type: text}]"
    #expect(
      try ValidationTests.manifest(yaml).problems.map(\.message) == [
        "signature renderer \"sparkline\" isn't in the app's kit"
      ]
    )
  }

  @Test func typeClocksComeBeforeSubtypeClocks() throws {
    let yaml =
      ValidationTests.base
      + "\nconditions: [Good, Bad]\nclocks: [serviceRisk]\nfields: []\n"
      + "subtypes: [{key: a, label: A, presets: {clock: [mediaRot, serviceRisk]}}]"
    let effective = try ValidationTests.manifest(yaml).resolve(subtype: "a")
    #expect(effective.clocks.map(\.name) == ["serviceRisk", "mediaRot"])
  }

  @Test func wineRunsItsDrinkingWindow() throws {
    #expect(try Catalogue.bundled().resolve("wine", subtype: nil).clocks.map(\.name) == ["drinkingWindow"])
  }

  @Test func everyRendererATypeUsesIsInTheKit() throws {
    for manifest in try Catalogue.bundled().manifests {
      for signature in manifest.signatures {
        #expect(SignatureRenderer(rawValue: signature.renderer) != nil)
      }
    }
  }
}

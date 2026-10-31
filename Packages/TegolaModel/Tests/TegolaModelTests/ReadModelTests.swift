import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

@Suite struct ReadModelTests {
  static let euro = Currency("EUR")!

  @Test func theSummaryCountsCopiesOfWhatsOwnedAndKept() throws {
    var harness = Harness()
    let kept = try harness.add(values: [.value: .money(Money(minorUnits: 5_000, currency: Self.euro))])
    _ = try harness.add("thing", "Meeples", bulk: .quantity, quantity: 4)
    _ = try harness.add(ownership: .wanted)
    _ = try harness.add(ownership: .borrowed)
    let gone = try harness.add(values: [.value: .money(Money(minorUnits: 9_000, currency: Self.euro))])
    try harness.perform(.letGo(gone, .gifted))
    let on = ShelfSummary(shelf: harness.shelf, money: .on, now: Harness.start)
    #expect(on.count == 5)
    #expect(on.value == [Money(minorUnits: 5_000, currency: Self.euro)])
    #expect(on.wanted == 1)
    #expect(ShelfSummary(shelf: harness.shelf, money: .off, now: Harness.start).value == nil)
    _ = kept
  }

  @Test func theTodayStripShowsOnlyItsNonEmptyLines() throws {
    var harness = Harness()
    #expect(TodayStrip(shelf: harness.shelf, now: Harness.start, statuses: [:]).lines.isEmpty)
    let id = try harness.add()
    _ = try harness.add(origin: .captured)
    try harness.perform(.lend(id, to: .new(name: "Dara"), due: Harness.start + 3600, note: ""))
    let later = Harness.start + 7200
    #expect(TodayStrip(shelf: harness.shelf, now: later, statuses: [:]).lines == [.toTidy(1), .overdue(1)])
    #expect(
      TodayStrip(shelf: harness.shelf, now: Harness.start, statuses: [id: .watch]).lines
        == [.toTidy(1), .needAttention(1)]
    )
  }

  @Test func placesShowOnceTwoExist() throws {
    var harness = Harness()
    let id = try harness.add()
    try harness.perform(.setPlace([id], PlacePath(typed: "Office")))
    #expect(!ShelfSummary(shelf: harness.shelf, money: .off, now: Harness.start).showsPlaces)
    try harness.perform(.setPlace([id], PlacePath(typed: "Attic")))
    #expect(ShelfSummary(shelf: harness.shelf, money: .off, now: Harness.start).showsPlaces)
  }

  @Test func aCollectionsMetaLineCountsAndNamesItsNoun() throws {
    var harness = Harness()
    let id = try harness.add("music", "Kid A")
    _ = try harness.add("music", "Homogenic")
    try harness.perform(.lend(id, to: .new(name: "Max"), due: nil, note: ""))
    let collection = try #require(harness.shelf.collections.values.first)
    let meta = CollectionMeta(collection: collection, shelf: harness.shelf, catalogue: Harness.catalogue)
    #expect(meta.count == 2)
    #expect(meta.lent == 1)
    #expect(meta.noun == "Releases")
  }

  /// F4: every v1 type shows the seven slots, in the product's order.
  @Test(arguments: Catalogue.enabledInV1)
  func theSevenSlotsAreTheSameForEveryType(_ type: TypeManifest.ID) {
    #expect(ObjectSlots.order == [.hero, .spine, .status, .signature, .fields, .actions, .history])
  }

  @Test func theObjectsSlotsHoldItsSpineLadderSetAndActions() throws {
    var harness = Harness()
    let id = try harness.add(
      subtype: "saturn",
      values: [
        .year: .year(1998), .paid: .money(Money(minorUnits: 12_000, currency: Self.euro)),
        .field("publisher"): .text("Treasure"), .axis("boxCondition"): .text("Very good"),
        .field("inserts"): .options(["manual", "disc"]),
      ]
    )
    let object = try #require(harness.shelf.objects[id])
    let manifest = try #require(Harness.catalogue.manifest("video-game"))
    let type = try Harness.catalogue.resolve("video-game", subtype: "saturn")
    let on = ObjectSlots(object: object, type: type, manifest: manifest, shelf: harness.shelf, money: .on)
    #expect(on.spine.map(\.label) == ["Released", "Paid"])
    #expect(on.ladder.map(\.grade) == [nil, "Very good", nil])
    #expect(on.set?.slots == ["case", "manual", "disc", "spine card"])
    #expect(on.set?.present == ["manual", "disc"])
    #expect(on.fields.map(\.field.key) == ["publisher", "inserts"])
    #expect(on.actions == [.edit, .photo, .lend, .mightLetGo, .letGo])
    let off = ObjectSlots(object: object, type: type, manifest: manifest, shelf: harness.shelf, money: .off)
    #expect(off.spine.map(\.label) == ["Released"])
  }
}

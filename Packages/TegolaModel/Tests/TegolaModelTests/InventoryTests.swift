import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

/// T8.3: the inventory document's model (F17).
@Suite struct InventoryTests {
  static let euro = Currency("EUR")!

  @Test func itListsWhatCountsWithConditionPlaceAndPaid() throws {
    var harness = Harness()
    let silvergun = try harness.add(
      subtype: "saturn",
      values: [
        .paid: .money(Money(minorUnits: 12_000, currency: Self.euro)), .axis("boxCondition"): .text("Very good"),
      ]
    )
    try harness.perform(.setPlace([silvergun], PlacePath(typed: "Office › Shelf 2")))
    try harness.perform(.attachPhoto(silvergun, fileName: "a.jpg", takenAt: Harness.start))
    let kidA = try harness.add("music", "Kid A", subtype: "vinyl", values: [.condition: .text("Near Mint")])
    _ = try harness.add("music", "Debut", ownership: .wanted)
    _ = try harness.add("music", "Blue Train", ownership: .borrowed)
    let gone = try harness.add("music", "Amnesiac")
    try harness.perform(.letGo(gone, .gifted))
    _ = try harness.add("thing", "Meeples", bulk: .quantity, quantity: 4)

    let document = InventoryDocument(shelf: harness.shelf, catalogue: Harness.catalogue, date: Harness.start)
    let items = document.sections.flatMap(\.items)
    // Promise 4: what's wanted, borrowed or let go isn't on it.
    #expect(Set(items.map(\.title)) == ["Radiant Silvergun", "Kid A", "Meeples"])
    #expect(document.count == 6)
    let game = try #require(items.first { $0.id == silvergun })
    #expect(game.condition == ["Box: Very good"])
    #expect(game.place == "Office › Shelf 2")
    #expect(game.photo == "a.jpg")
    #expect(game.paid == Money(minorUnits: 12_000, currency: Self.euro))
    #expect(items.first { $0.id == kidA }?.condition == ["Near Mint"])
    #expect(document.paidTotals == [Money(minorUnits: 12_000, currency: Self.euro)])
  }

  @Test func anEmptyShelfHasAnEmptyDocument() {
    let document = InventoryDocument(shelf: Shelf(), catalogue: Harness.catalogue, date: Harness.start)
    #expect(document.sections.isEmpty)
    #expect(document.count == 0)
  }
}

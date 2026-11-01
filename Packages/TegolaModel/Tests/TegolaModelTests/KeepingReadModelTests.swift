import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

/// T8.1: the wishlist, Might let go and the archive (F16).
@Suite struct KeepingReadModelTests {
  static let euro = Currency("EUR")!

  @Test func theWishlistPutsGrailsFirstThenPriorityThenTitle() throws {
    var harness = Harness()
    let low = try harness.add("music", "Amnesiac", ownership: .wanted)
    try harness.perform(.setWanted(low, priority: 3, priceCap: nil))
    let high = try harness.add("music", "Vespertine", ownership: .wanted)
    try harness.perform(.setWanted(high, priority: 1, priceCap: Money(minorUnits: 4_000, currency: Self.euro)))
    let unranked = try harness.add("music", "Debut", ownership: .wanted)
    let grail = try harness.add("music", "Kid A", ownership: .wanted)
    try harness.perform(.setGrail(grail, true))
    _ = try harness.add("music", "Homogenic")
    _ = try harness.add("music", "Blue Train", ownership: .borrowed)

    let off = Wishlist(shelf: harness.shelf, money: .off)
    #expect(off.wants.map(\.id) == [grail, high, low, unranked])
    #expect(off.wants.allSatisfy { $0.priceCap == nil })
    let on = Wishlist(shelf: harness.shelf, money: .on)
    #expect(on.wants.first { $0.id == high }?.priceCap == Money(minorUnits: 4_000, currency: Self.euro))
  }

  /// It arrived: once owned, it leaves the wishlist and its history stays.
  @Test func itArrivedLeavesTheWishlist() throws {
    var harness = Harness()
    let id = try harness.add("music", "Debut", ownership: .wanted)
    try harness.perform(.setOwned(id))
    #expect(Wishlist(shelf: harness.shelf, money: .off).isEmpty)
    let events = harness.log.filter { $0.objectID == id }.map(\.kind.name)
    #expect(events.first == "added")
    #expect(events.last == "owned")
  }

  @Test func mightLetGoListsOnlyWhatsOwnedAndKept() throws {
    var harness = Harness()
    let flagged = try harness.add("music", "Kid A")
    try harness.perform(.setMightLetGo(flagged, true))
    let gone = try harness.add("music", "Amnesiac")
    try harness.perform(.setMightLetGo(gone, true))
    try harness.perform(.letGo(gone, .gifted))
    _ = try harness.add("music", "Debut")
    #expect(MightLetGo(shelf: harness.shelf).objects.map(\.id) == [flagged])
  }

  /// F16: the archive answers *did I ever own this?*, the newest first, by reason; a sale's price only with money on.
  @Test func theArchiveKeepsWhatLeftAndWhy() throws {
    var harness = Harness()
    let sold = try harness.add("music", "Kid A")
    try harness.perform(.letGo(sold, .sold(price: Money(minorUnits: 2_500, currency: Self.euro))))
    let lost = try harness.add("music", "Amnesiac")
    try harness.perform(.letGo(lost, .lost))
    _ = try harness.add("music", "Debut")

    let off = Archive(shelf: harness.shelf, money: .off)
    #expect(off.entries.map(\.id) == [lost, sold])
    #expect(off.entries.allSatisfy { $0.price == nil })
    #expect(off.groups.map(\.why) == [.sold, .lost])
    #expect(Archive(shelf: harness.shelf, money: .on).entries.last?.price?.minorUnits == 2_500)
    // Promise 4: what left never counts.
    #expect(ShelfSummary(shelf: harness.shelf, money: .off, now: Harness.start).count == 1)
  }
}

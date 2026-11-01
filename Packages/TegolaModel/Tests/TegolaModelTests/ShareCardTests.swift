import Foundation
import TegolaCatalogue
import TegolaModelTesting
import Testing

@testable import TegolaModel

/// T7.4: share cards (F14, D-78). No card, of either kind, with money on or off, carries what was paid.
@Suite struct ShareCardTests {
  static let euro = Currency("EUR")!
  static let paid = Money(minorUnits: 12_000, currency: euro)

  func card(
    _ kind: ShareCard.Kind,
    _ id: ObjectID,
    in harness: Harness,
    money: MoneyVisibility,
    asking: Money? = nil
  ) throws -> ShareCard {
    let object = try #require(harness.shelf.objects[id])
    let manifest = try #require(Harness.catalogue.manifest(object.typeID))
    let type = try Harness.catalogue.resolve(object.typeID, subtype: object.subtype)
    return ShareCard(
      kind,
      object: object,
      type: type,
      manifest: manifest,
      shelf: harness.shelf,
      money: money,
      askingPrice: asking
    )
  }

  @Test func theRecordHasTheCataloguesFactsAndMyCopyAddsTheCopys() throws {
    var harness = Harness()
    let id = try harness.add(
      subtype: "saturn",
      values: [
        .year: .year(1998), .paid: .money(Self.paid), .value: .money(Self.paid),
        .field("publisher"): .text("Treasure"), .field("region"): .text("NTSC-J"),
        .axis("boxCondition"): .text("Very good"), .field("inserts"): .options(["manual", "disc"]),
        .notes: .text("Bought from Kenji"),
      ]
    )
    try harness.perform(.attachPhoto(id, fileName: "a.jpg", takenAt: Harness.start))

    let record = try card(.record, id, in: harness, money: .on)
    #expect(record.title == "Radiant Silvergun")
    #expect(record.subtype == "saturn")
    #expect(record.facts.map(\.key) == [.year, .field("publisher")])
    #expect(record.photos.isEmpty)
    #expect(record.askingPrice == nil)

    let mine = try card(.myCopy, id, in: harness, money: .on)
    #expect(
      mine.facts.map(\.key) == [
        .year, .field("publisher"), .field("region"), .field("inserts"), .axis("boxCondition"),
      ]
    )
    #expect(mine.facts.last?.label == "Box")
    #expect(mine.photos.count == 1)
  }

  @Test func anAskingPriceShowsOnlyOnMyCopyWithMoneyOn() throws {
    var harness = Harness()
    let id = try harness.add()
    let asking = Money(minorUnits: 20_000, currency: Self.euro)
    #expect(try card(.myCopy, id, in: harness, money: .on, asking: asking).askingPrice == asking)
    #expect(try card(.myCopy, id, in: harness, money: .off, asking: asking).askingPrice == nil)
    #expect(try card(.record, id, in: harness, money: .on, asking: asking).askingPrice == nil)
  }

  /// F14's *Done when*, as a property over random shelves of every v1 type: whatever the collector did, no fact on any
  /// card is money, and none is paid, value, acquired or the notes.
  @Test(arguments: Catalogue.enabledInV1)
  func noCardEverCarriesWhatWasPaid(_ type: TypeManifest.ID) throws {
    let private_: Set<FieldKey> = [.paid, .value, .acquired, .notes]
    for seed in 1...UInt64(20) {
      var harness = Harness()
      var generator = CommandGenerator(type: type, catalogue: Harness.catalogue, seed: seed &* 104_729)
      for _ in 0..<40 {
        let (command, source) = generator.next(on: harness.shelf)
        _ = try? harness.perform(command, as: source)
      }
      for id in harness.shelf.objects.keys {
        for kind in [ShareCard.Kind.record, .myCopy] {
          for money in [MoneyVisibility.on, .off] {
            let shared = try card(kind, id, in: harness, money: money)
            for fact in shared.facts {
              if case .money = fact.value { Issue.record("money on a card: \(fact.key), seed \(seed)") }
              #expect(!private_.contains(fact.key), "\(fact.key) on a card, seed \(seed)")
            }
            #expect(shared.askingPrice == nil)
          }
        }
      }
    }
  }

  /// PD-071: the wishlist reveals wants, never holdings.
  @Test func theWishlistCardListsOnlyWhatsWantedGrailsFirst() throws {
    var harness = Harness()
    _ = try harness.add("music", "Kid A")
    let want = try harness.add("music", "Amnesiac", ownership: .wanted)
    let grail = try harness.add("music", "Vespertine", ownership: .wanted)
    try harness.perform(.setGrail(grail, true))
    _ = try harness.add("music", "Blue Train", ownership: .borrowed)
    #expect(WishlistCard(shelf: harness.shelf).wants.map(\.id) == [grail, want])
    #expect(WishlistCard(shelf: harness.shelf).wants.first?.isGrail == true)
  }
}

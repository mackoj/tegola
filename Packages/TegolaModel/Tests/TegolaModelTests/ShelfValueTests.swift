import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

@Suite struct ShelfValueTests {
  static func id<Tag>(_ n: Int) -> Identifier<Tag> {
    Identifier(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!)
  }

  /// The log stores each event's kind as JSON, so every kind must come back as it went in.
  @Test func eventsRoundTripThroughJSON() throws {
    let at = Date(timeIntervalSince1970: 1_800_000_000)
    let euro = try #require(Currency("EUR"))
    let object = ShelfObject(
      id: Self.id(1),
      collectionID: Self.id(2),
      typeID: "video-game",
      subtype: "saturn",
      workID: nil,
      values: [.title: .text("Radiant Silvergun"), .paid: .money(Money(minorUnits: 12_000, currency: euro))],
      auto: [.field("publisher")],
      placeID: nil,
      bulk: .rows,
      quantity: 1,
      ownership: .owned,
      identity: .confirmed,
      isGrail: true,
      mightLetGo: false,
      priority: nil,
      priceCap: nil,
      letGo: nil,
      promotedFrom: nil,
      createdAt: at,
      updatedAt: at
    )
    let kinds: [ShelfEvent.Kind] = [
      .added(object, origin: .firstPiece(story: "Found it in Akihabara")),
      .edited(Self.id(1), changes: [.field("region"): .text("NTSC-J"), .notes: nil]),
      .letGo(Self.id(1), LetGo(reason: .sold(price: Money(minorUnits: 50_000, currency: euro)), at: at)),
    ]
    for kind in kinds {
      let event = ShelfEvent(id: Self.id(9), seq: 3, at: at, source: .collector, batchID: nil, kind: kind)
      let decoded = try JSONDecoder().decode(ShelfEvent.self, from: JSONEncoder().encode(event))
      #expect(decoded == event)
      #expect(decoded.objectID == Self.id(1))
    }
  }

  @Test func aValueMapIsStoredAsAnObjectKeyedByDescription() throws {
    let values: [FieldKey: FieldValue] = [
      .title: .text("Kid A"), .field("rpm"): .text("33⅓"), .axis("box"): .text("VG"),
    ]
    let json = try #require(String(data: JSONEncoder().encode(values), encoding: .utf8))
    #expect(json.hasPrefix("{"))
    #expect(json.contains("\"field.rpm\""))
    #expect(try JSONDecoder().decode([FieldKey: FieldValue].self, from: Data(json.utf8)) == values)
    #expect(FieldKey(description: "colour") == nil)
  }

  @Test func onlyOwnedObjectsThatStayCount() {
    #expect(ShelfObject.Ownership.allCases.filter { $0 == .owned }.count == 1)
  }
}

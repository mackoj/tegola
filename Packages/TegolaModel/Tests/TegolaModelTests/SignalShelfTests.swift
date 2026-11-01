import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

/// M4's exit test, automated (page 52 P2): a 200-object shelf, built the same way every time, gives a signal list
/// that was checked by hand against D-56 and pinned here. The test with collectors (8 of 10 agree) is the owner's.
@Suite struct SignalShelfTests {
  /// 80 video games across the five subtypes and code cards, 50 records, 40 board games, 30 things. Ages spread over
  /// 15 to 39 years; some batteries swapped, some fitted later, two signals dismissed.
  static func shelf() throws -> Harness {
    var harness = Harness()
    let year = 2027  // Harness.start is in January 2027.
    let subtypes = ["game-boy", "n64", "saturn", "ps1", "neo-geo"]
    for i in 0..<80 {
      let age = 15 + (i * 7) % 25
      if i % 10 == 9 {
        // A download code: every third one expires within the month.
        let days = i % 3 == 0 ? 30 : 400
        _ = try harness.add(
          "video-game",
          "Code \(i)",
          values: [
            .year: .year(year - age), .field("platform"): .text("Nintendo Switch"),
            .field("media"): .text("Download code"), .field("region"): .text("PAL"),
            .field("codeExpires"): .date(Harness.start + Double(days) * 86_400),
          ]
        )
        continue
      }
      let subtype = subtypes[i % 5]
      var values: [FieldKey: FieldValue] = [.year: .year(year - age), .field("region"): .text("PAL")]
      if subtype == "neo-geo" { values[.field("board")] = .text("AES") }
      if i % 4 == 1 { values[.field("saveBattery")] = .date(Calendar.utc.date(from: DateComponents(year: 2010))!) }
      let id = try harness.add("video-game", "Game \(i)", subtype: subtype, values: values)
      if i % 6 == 2 { try harness.perform(.logEvent(id, kind: ShelfEvent.Kind.servicedKind, note: "")) }
    }
    for i in 0..<50 {
      _ = try harness.add(
        "music",
        "Record \(i)",
        subtype: ["vinyl", "cd", "cassette", "other"][i % 4],
        values: [.year: .year(1960 + i)]
      )
    }
    for i in 0..<40 { _ = try harness.add("board-games", "Board game \(i)") }
    for i in 0..<30 { _ = try harness.add("thing", "Thing \(i)") }
    // The collector disagrees with two readings.
    for title in ["Game 6", "Game 16"] {
      let id = try #require(harness.shelf.objects.values.first { $0.title == title }?.id)
      let object = try #require(harness.shelf.objects[id])
      let type = try Harness.catalogue.resolve(object.typeID, subtype: object.subtype)
      let signal = try #require(signals(for: object, type: type, now: harness.clock, calendar: .utc).first)
      try harness.perform(.dismissSignal(id, signal))
    }
    return harness
  }

  @Test func theTwoHundredObjectShelfGivesThePinnedSignalList() throws {
    let harness = try Self.shelf()
    #expect(harness.shelf.objects.count == 200)
    let signals = ShelfSignals(shelf: harness.shelf, catalogue: Harness.catalogue, now: harness.clock, calendar: .utc)
    let feed = signals.feed.map { entry in
      "\(harness.shelf.objects[entry.object]!.title) \(entry.signal.clock) \(entry.signal.status)"
    }
    // Checked by hand against D-56 (2026-11-01): carts past 35 years act; codes inside 60 days and carts of 25 to
    // 34 years watch, soonest change first. Swapped carts, carts with a later battery, Games 6 and 16 (dismissed),
    // discs (held back), and every record, board game and thing are absent.
    #expect(
      feed == [
        "Game 10 saveBattery act", "Game 35 saveBattery act", "Game 46 saveBattery act", "Game 60 saveBattery act",
        "Game 71 saveBattery act", "Code 9 codeExpiry watch", "Code 39 codeExpiry watch", "Code 69 codeExpiry watch",
        "Game 31 saveBattery watch", "Game 70 saveBattery watch", "Game 66 saveBattery watch",
        "Game 30 saveBattery watch", "Game 55 saveBattery watch",
      ]
    )
    let attention = signals.statuses.values.filter(\.needsAttention).count
    #expect(attention == 13)
  }
}

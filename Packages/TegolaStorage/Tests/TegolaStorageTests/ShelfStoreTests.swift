import Dependencies
import Foundation
import SQLiteData
import TegolaCatalogue
import TegolaModel
import TegolaModelTesting
import Testing

@testable import TegolaStorage

struct StoreHarness {
  static let catalogue = try! Catalogue.bundled()

  let store: ShelfStore
  let ids = Counter()
  var clock = Date(timeIntervalSince1970: 1_800_000_000)

  init() throws {
    store = try ShelfStore(
      database: DatabaseQueue(configuration: ShelfStore.configuration()),
      catalogue: Self.catalogue
    )
  }

  func context(_ source: ShelfEvent.Source = .collector) -> PlanContext {
    let ids = ids
    return PlanContext(at: clock, source: source, catalogue: Self.catalogue, makeID: { ids.next() })
  }

  @discardableResult
  mutating func perform(_ command: ShelfCommand, as source: ShelfEvent.Source = .collector) throws -> CommandReceipt {
    defer { clock += 60 }
    return try store.perform(command, context: context(source))
  }
}

@Suite struct ShelfStoreTests {
  static func draft(_ title: String, subtype: String? = nil) -> ObjectDraft {
    ObjectDraft(type: "video-game", subtype: subtype, values: [.title: .text(title)])
  }

  @Test func performWritesTheLogAndTheProjectionTogether() throws {
    var harness = try StoreHarness()
    let receipt = try harness.perform(
      .add(Self.draft("Radiant Silvergun", subtype: "saturn"), to: .new(name: "Games"), origin: .typed)
    )
    #expect(receipt.events.map(\.kind.name) == ["collectionCreated", "added"])
    let id = try #require(receipt.createdObjects.first)
    #expect(receipt.createdCollections.count == 1)
    let shelf = try harness.store.shelf()
    #expect(shelf.objects[id]?.title == "Radiant Silvergun")
    #expect(shelf.lastSeq == 2)
    #expect(try harness.store.log() == receipt.events)
    #expect(shelf == apply(receipt.events, to: Shelf()))
  }

  @Test func aRefusedCommandWritesNothing() throws {
    var harness = try StoreHarness()
    try harness.perform(.add(Self.draft("Doom"), to: .new(name: "Games"), origin: .typed))
    let before = try harness.store.shelf()
    #expect(throws: ShelfRuleViolation.emptyTitle) {
      try harness.perform(.add(Self.draft(""), to: .new(name: "More games"), origin: .typed))
    }
    #expect(try harness.store.shelf() == before)
    #expect(try harness.store.log().count == 2)
  }

  @Test func historyIsTheObjectsEventsInOrder() throws {
    var harness = try StoreHarness()
    let id = try #require(
      try harness.perform(.add(Self.draft("Doom"), to: .new(name: "Games"), origin: .typed)).createdObjects.first
    )
    try harness.perform(.edit(id, values: [.notes: .text("Shareware disk")]))
    try harness.perform(.setPlace([id], PlacePath(typed: "Office › Shelf 2")))
    try harness.perform(.logEvent(id, kind: "cleaned", note: ""))
    #expect(try harness.store.history(of: id).map(\.kind.name) == ["added", "edited", "placed", "logged"])
  }

  @Test func seqCarriesOnAcrossCommands() throws {
    var harness = try StoreHarness()
    try harness.perform(.add(Self.draft("Doom"), to: .new(name: "Games"), origin: .typed))
    let second = try harness.perform(.createCollection(name: "Shelf two", type: nil))
    #expect(second.events.map(\.seq) == [3])
  }

  /// SyncEngine's rule: a row inserted without an id gets one from `uuid()`, which the `uuid` dependency backs, so
  /// it's deterministic (D-24). Review of M2, finding 7: the platform's own `uuid()` hid that none was registered.
  @Test func aRowWithoutAnIdGetsOneFromTheDependency() throws {
    let harness = try StoreHarness()
    try withDependencies {
      $0.uuid = .incrementing
    } operation: {
      try harness.store.database.write { db in
        try #sql(
          """
          INSERT INTO "persons" ("name", "lastUsedAt", "data") VALUES ('Max', '2026-10-31 00:00:00.000', '{}')
          """
        )
        .execute(db)
      }
    }
    let ids = try harness.store.database.read { db in try PersonRow.select(\.id).fetchAll(db) }
    #expect(ids == [UUID(0)])
  }

  /// History only appends (PD-051), and SQLite enforces it. Review of M2, finding 8.
  @Test func theLogCantBeChangedOrEmptied() throws {
    var harness = try StoreHarness()
    try harness.perform(.createCollection(name: "Games", type: nil))
    #expect(throws: (any Error).self) {
      try harness.store.database.write { db in try #sql(#"UPDATE "events" SET "kind" = 'x'"#).execute(db) }
    }
    #expect(throws: (any Error).self) {
      try harness.store.database.write { db in try #sql(#"DELETE FROM "events""#).execute(db) }
    }
    #expect(try harness.store.log().count == 1)
  }

  /// Review of M2, finding 1: a real clock has sub-millisecond times, and the rebuild must still match.
  @Test func aRealClockRebuildsExactly() throws {
    var harness = try StoreHarness()
    harness.clock = Date(timeIntervalSince1970: 1_800_000_000.123456)
    let id = try #require(
      try harness.perform(.add(Self.draft("Doom"), to: .new(name: "Games"), origin: .typed)).createdObjects.first
    )
    let second = try harness.perform(.logEvent(id, kind: "cleaned", note: ""))
    let live = try harness.store.shelf()
    #expect(try harness.store.log().suffix(1) == second.events)
    try harness.store.rebuildProjection()
    #expect(try harness.store.shelf() == live)
  }

  /// Review of M2, finding 2: the log replays in the order commands ran, even when the clock goes back.
  @Test func aClockGoingBackDoesntReorderTheLog() throws {
    var harness = try StoreHarness()
    let id = try #require(
      try harness.perform(.add(Self.draft("Doom"), to: .new(name: "Games"), origin: .typed)).createdObjects.first
    )
    harness.clock += 1000
    try harness.perform(.edit(id, values: [.notes: .text("first")]))
    harness.clock -= 2000
    try harness.perform(.edit(id, values: [.notes: .text("second")]))
    try harness.store.rebuildProjection()
    #expect(try harness.store.shelf().objects[id]?.values[.notes] == .text("second"))
  }

  /// The replay test (PLAN §3.1): for random command sequences on every v1 type, rebuilding the projection from the
  /// log gives the tables the commands left, and both equal the model's own replay.
  @Test(arguments: Catalogue.enabledInV1)
  func theProjectionRebuildsFromTheLog(_ type: TypeManifest.ID) throws {
    for seed in 1...UInt64(8) {
      var harness = try StoreHarness()
      var generator = CommandGenerator(type: type, catalogue: StoreHarness.catalogue, seed: seed &* 104_729)
      var appended = 0
      for _ in 0..<50 {
        let (command, source) = generator.next(on: try harness.store.shelf())
        if let receipt = try? harness.perform(command, as: source) { appended += receipt.events.count }
      }
      let live = try harness.store.shelf()
      let log = try harness.store.log()
      #expect(log.count == appended, "the log is every event, once")
      #expect(apply(log, to: Shelf()) == live, "seed \(seed): the tables differ from the model's replay")
      try harness.store.rebuildProjection()
      #expect(try harness.store.shelf() == live, "seed \(seed): the rebuilt tables differ")
      #expect(!live.objects.isEmpty)
    }
  }
}

@Suite struct SeedTests {
  @Test func theSeedPlantsThroughPerform() throws {
    let harness = try StoreHarness()
    let ids = harness.ids
    try Seed.plant(in: harness.store, at: harness.clock, makeID: { ids.next() })
    let shelf = try harness.store.shelf()
    #expect(Set(shelf.objects.values.map(\.typeID)) == Set(Catalogue.enabledInV1))
    // M4 grew it from 16 to 105, in four more collections.
    #expect(shelf.objects.count == 105)
    #expect(shelf.collections.count == 8)
    #expect(shelf.objects.values.contains { $0.identity == .unconfirmed })
    #expect(shelf.objects.values.contains { $0.identity == .needsDetails })
    #expect(shelf.objects.values.contains { $0.ownership == .wanted })
    #expect(shelf.objects.values.contains { $0.ownership == .borrowed })
    #expect(shelf.objects.values.contains { $0.letGo != nil })
    #expect(shelf.objects.values.contains { $0.bulk == .quantity })
    #expect(shelf.loans.values.contains { $0.isOpen && $0.direction == .out })
    #expect(apply(try harness.store.log(), to: Shelf()) == shelf)
  }

  /// Journey 5's starting point: exactly one object needs attention, a Game Boy cartridge whose battery is due.
  @Test func theSeedHasOneSignalThatNeedsAttention() throws {
    let harness = try StoreHarness()
    let ids = harness.ids
    try Seed.plant(in: harness.store, at: harness.clock, makeID: { ids.next() })
    let shelf = try harness.store.shelf()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let signals = ShelfSignals(shelf: shelf, catalogue: harness.store.catalogue, now: harness.clock, calendar: calendar)
    let feed = signals.feed.compactMap { shelf.objects[$0.object] }
    #expect(feed.map(\.title) == ["Tetris"])
    #expect(feed.first?.subtype == "game-boy")
    // The rest of what the clocks read: swaps logged, one dismissal, a code that's good.
    #expect(shelf.objects.values.filter { $0.signalState?.lastServiced != nil }.count == 11)
    #expect(shelf.objects.values.contains { $0.signalState?.dismissed.isEmpty == false })
    #expect(signals.statuses.values.filter { $0 == .good }.count == 13)
  }
}

@Suite struct SettingsTests {
  @Test func moneyIsOffUntilTheCollectorTurnsItOn() throws {
    let harness = try StoreHarness()
    #expect(try harness.store.money() == .off)
    try harness.store.set(.money, to: MoneyVisibility.on.rawValue)
    #expect(try harness.store.money() == .on)
    try harness.store.set(.money, to: MoneyVisibility.off.rawValue)
    #expect(try harness.store.money() == .off)
    let rows = try harness.store.database.read { db in try SettingRow.fetchCount(db) }
    #expect(rows == 1)
  }

  /// The clock settings (F15, D-20): the offer's answer and the opt-in clocks reach the screens' snapshot.
  @Test func theClockSettingsReachTheSnapshot() throws {
    let harness = try StoreHarness()
    var snapshot = try harness.store.database.read { db in try ShelfRequest().fetch(db) }
    #expect(snapshot.notificationsOffer == nil)
    #expect(snapshot.optedInClocks.isEmpty)
    try harness.store.set(.notificationsOffer, to: "accepted")
    try harness.store.set(.optedInClocks, to: "unfinished")
    snapshot = try harness.store.database.read { db in try ShelfRequest().fetch(db) }
    #expect(snapshot.notificationsOffer == "accepted")
    #expect(snapshot.optedInClocks == ["unfinished"])
  }
}

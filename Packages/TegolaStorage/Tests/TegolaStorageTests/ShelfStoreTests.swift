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

  /// An import is one batch in the log and one row in `importBatches`; its undo soft-deletes what nobody touched,
  /// keeps the rest, and a rebuild agrees (PD-047, D-12).
  @Test func anImportAndItsUndoSurviveARebuild() throws {
    var harness = try StoreHarness()
    let batch = ImportBatch(
      importer: "spreadsheet",
      fileName: "Jeux collection.csv",
      collectionName: "Jeux",
      rows: [Self.draft("Tetris", subtype: "game-boy"), Self.draft("Doom")]
    )
    let receipt = try harness.perform(.importBatch(batch), as: .import)
    let batchID = try #require(receipt.batchID)
    let ids = receipt.createdObjects
    #expect(ids.count == 2)
    #expect(try harness.store.shelf().batches[batchID]?.rowCount == 2)
    try harness.perform(.edit(ids[1], values: [.notes: .text("doublon")]))
    try harness.perform(.undoBatch(batchID))
    let live = try harness.store.shelf()
    #expect(live.objects[ids[0]] == nil && live.objects[ids[1]] != nil)
    #expect(live.batches[batchID]?.undoneAt != nil)
    // The removed row is still in the table, marked, never dropped.
    let rows = try harness.store.database.read { db in try ObjectRow.fetchAll(db) }
    #expect(rows.count == 2 && rows.filter { $0.deletedAt != nil }.map(\.id) == [ids[0].rawValue])
    try harness.store.rebuildProjection()
    #expect(try harness.store.shelf() == live)
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
    #expect(shelf.objects.count == 16)
    #expect(shelf.collections.count == 4)
    #expect(shelf.objects.values.contains { $0.identity == .unconfirmed })
    #expect(shelf.objects.values.contains { $0.identity == .needsDetails })
    #expect(shelf.objects.values.contains { $0.ownership == .wanted })
    #expect(shelf.objects.values.contains { $0.ownership == .borrowed })
    #expect(shelf.objects.values.contains { $0.letGo != nil })
    #expect(shelf.objects.values.contains { $0.bulk == .quantity })
    #expect(shelf.loans.values.contains { $0.isOpen && $0.direction == .out })
    #expect(apply(try harness.store.log(), to: Shelf()) == shelf)
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
}

/// The first piece's settings and its waiting Thing, as the shelf's query reads them (T5.2, T5.3).
@Suite struct FirstPieceStorageTests {
  func snapshot(_ harness: StoreHarness) throws -> ShelfSnapshot {
    try harness.store.database.read { db in try ShelfRequest().fetch(db) }
  }

  @Test func theAppOpensOnTheFirstPieceUntilThereIsOneOrItsSkipped() throws {
    let harness = try StoreHarness()
    #expect(try snapshot(harness).opensOnFirstPiece)
    try harness.store.set(.firstPieceSkipped, to: "true")
    #expect(try !snapshot(harness).opensOnFirstPiece)

    var other = try StoreHarness()
    let draft = ObjectDraft(type: "video-game", subtype: "n64", values: [.title: .text("Ocarina of Time")])
    try other.perform(.firstPiece(draft, story: "Had it since I was a kid", catalogue: StoreHarness.catalogue))
    #expect(try !snapshot(other).opensOnFirstPiece)
  }

  @Test func countMeInIsKeptAsOneSortedRow() throws {
    let harness = try StoreHarness()
    #expect(try snapshot(harness).typeTesters == TypeTesters())
    try harness.store.set(.typeTesters, to: TypeTesters().adding("wine").adding("watches").setting)
    #expect(try snapshot(harness).typeTesters == TypeTesters(["watches", "wine"]))
    let row = try harness.store.database.read { db in try SettingRow.find(SettingKey.typeTesters.id).fetchOne(db) }
    #expect(row?.value == "watches,wine")
  }

  /// A watch saved as a Thing still knows it's a watch after the projection is stored and the log replayed.
  @Test func aWaitingThingSurvivesStorageAndReplay() throws {
    var harness = try StoreHarness()
    let draft = ObjectDraft.recognised(
      as: "watches",
      values: [.title: .text("Omega Seamaster"), .year: .year(1968)],
      catalogue: StoreHarness.catalogue
    )
    try harness.perform(.firstPiece(draft, story: "From my grandfather", catalogue: StoreHarness.catalogue))
    let shelf = try harness.store.shelf()
    #expect(shelf.waiting(for: "watches").map(\.title) == ["Omega Seamaster"])
    #expect(apply(try harness.store.log(), to: Shelf()) == shelf)
  }
}

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
    store = try ShelfStore(database: DatabaseQueue(), catalogue: Self.catalogue)
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

  /// SyncEngine's rule: a row inserted without an id gets one from `uuid()` (D-24).
  @Test func aRowWithoutAnIdGetsOne() throws {
    let harness = try StoreHarness()
    try harness.store.database.write { db in
      try #sql(
        """
        INSERT INTO "persons" ("name", "lastUsedAt", "data") VALUES ('Max', '2026-10-31 00:00:00.000', '{}')
        """
      )
      .execute(db)
    }
    let count = try harness.store.database.read { db in try PersonRow.where { $0.id.isNot(nil) }.fetchCount(db) }
    #expect(count == 1)
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

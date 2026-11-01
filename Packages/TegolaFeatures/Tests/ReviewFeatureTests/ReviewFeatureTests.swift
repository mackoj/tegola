import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaCatalogue
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import ReviewFeature

func candidate(_ title: String, release: String, confidence: Double, publisher: String? = nil) -> LookupCandidate {
  var values: [FieldKey: FieldValue] = [.title: .text(title), .year: .year(1995)]
  if let publisher { values[.field("publisher")] = .text(publisher) }
  return LookupCandidate(
    releaseID: release,
    type: "video-game",
    subtype: "ps1",
    values: values,
    confidence: confidence,
    reasons: [.barcode],
    sources: [.init(name: "IGDB")]
  )
}

/// A capture with a title (so it's unconfirmed) whose lookup answered `answer`; returns its id.
@MainActor
func captured(_ title: String, answer: [LookupCandidate]) throws -> ObjectID {
  @Dependency(\.shelf) var shelf
  @Dependency(\.lookupQueue) var queue
  @Dependency(\.date.now) var now
  let draft = ObjectDraft(type: "video-game", subtype: "ps1", values: [.title: .text(title)])
  let id = try shelf.capture(.add(draft, to: .new(name: "Captures"), origin: .captured), .barcode("0711719200020"))
    .createdObjects[0]
  let request = try #require(try queue.load().requests.first { $0.objectID == id })
  try queue.record(request.id, .answered(answer), now)
  return id
}

@MainActor
func object(_ id: ObjectID) throws -> ShelfObject? {
  @Dependency(\.defaultDatabase) var database
  return try database.read { db in try ShelfRequest().fetch(db) }.shelf.objects[id]
}

/// T6.11 (F8): confirming fills only what's empty, from the lookup, then confirms; Confirm all is strong only.
@MainActor
@Suite(
  .dependencies {
    try $0.seededShelf()
    $0.lookupQueue = .store(ShelfStore(migrated: $0.defaultDatabase, catalogue: $0.catalogue))
  }
)
struct ReviewFeatureTests {
  @Test func confirmFillsWhatsEmptyAndConfirms() async throws {
    let id = try captured(
      "Ridge Racer",
      answer: [candidate("Ridge Racer", release: "r1", confidence: 0.97, publisher: "Namco")]
    )
    let store = TestStore(initialState: ReviewFeature.State()) { ReviewFeature() }
    store.exhaustivity = .off
    await store.send(.view(.onAppear))
    await store.receive(\.loaded)
    let row = try #require(store.state.review.rows.first { $0.id == id })
    #expect(row.isStrong)

    await store.send(.view(.confirmTapped(id)))
    await store.receive(\.loaded)
    let confirmed = try #require(try object(id))
    #expect(confirmed.identity == .confirmed)
    #expect(confirmed.values[.field("publisher")] == .text("Namco"))
    // Filled by the lookup: AUTO until the collector touches it (PD-045).
    #expect(confirmed.auto.contains(.field("publisher")))
    #expect(!store.state.review.rows.contains { $0.id == id })
  }

  /// Confirm all takes the strong matches and leaves the rest alone (F8).
  @Test func confirmAllIsStrongOnly() async throws {
    let strong = try captured(
      "Ridge Racer",
      answer: [candidate("Ridge Racer", release: "r1", confidence: 0.95, publisher: "Namco")]
    )
    let weak = try captured("Tekken", answer: [candidate("Tekken", release: "t1", confidence: 0.5, publisher: "Namco")])
    let store = TestStore(initialState: ReviewFeature.State()) { ReviewFeature() }
    store.exhaustivity = .off
    await store.send(.view(.onAppear))
    await store.receive(\.loaded)
    await store.send(.view(.confirmAllTapped))
    await store.receive(\.loaded)

    #expect(try object(strong)?.identity == .confirmed)
    #expect(try object(weak)?.identity == .unconfirmed)
  }

  /// "Which Tetris?": the collector picks, and the pick is what fills.
  @Test func aRowThatAsksTakesThePick() async throws {
    let id = try captured(
      "Tetris",
      answer: [
        candidate("Tetris", release: "gb", confidence: 0.7, publisher: "Nintendo"),
        candidate("Tetris Plus", release: "plus", confidence: 0.65, publisher: "Jaleco"),
      ]
    )
    let store = TestStore(initialState: ReviewFeature.State()) { ReviewFeature() }
    store.exhaustivity = .off
    await store.send(.view(.onAppear))
    await store.receive(\.loaded)
    #expect(store.state.review.rows.first { $0.id == id }?.asks == true)
    await store.send(.view(.candidatePicked(id, releaseID: "plus")))
    await store.send(.view(.confirmTapped(id)))
    await store.receive(\.loaded)
    #expect(try object(id)?.values[.field("publisher")] == .text("Jaleco"))
  }

  /// A row that asks, confirmed with nothing picked, is confirmed as written: nothing fills (D-75, review).
  @Test func aRowThatAsksWithNoPickConfirmsAsWritten() async throws {
    let id = try captured(
      "Tetris",
      answer: [
        candidate("Tetris", release: "gb", confidence: 0.7, publisher: "Nintendo"),
        candidate("Tetris Plus", release: "plus", confidence: 0.65, publisher: "Jaleco"),
      ]
    )
    let store = TestStore(initialState: ReviewFeature.State()) { ReviewFeature() }
    store.exhaustivity = .off
    await store.send(.view(.onAppear))
    await store.receive(\.loaded)
    await store.send(.view(.confirmTapped(id)))
    await store.receive(\.loaded)
    #expect(try object(id)?.identity == .confirmed)
    #expect(try object(id)?.values[.field("publisher")] == nil)
  }

  /// A typed value is the collector's: a lookup never overwrites it (promise 1).
  @Test func confirmingNeverOverwritesWhatWasTyped() async throws {
    let id = try captured("Ridge Racer", answer: [candidate("Ridge Racer Revolution", release: "r2", confidence: 0.95)])
    let store = TestStore(initialState: ReviewFeature.State()) { ReviewFeature() }
    store.exhaustivity = .off
    await store.send(.view(.onAppear))
    await store.receive(\.loaded)
    await store.send(.view(.confirmTapped(id)))
    await store.receive(\.loaded)
    #expect(try object(id)?.title == "Ridge Racer")
  }
}

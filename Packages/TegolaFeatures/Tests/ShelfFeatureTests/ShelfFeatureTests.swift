import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaClients
import TegolaModel
import Testing

@testable import ShelfFeature

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct ShelfFeatureTests {
  @Test func theSeedReadsAsTheShelfHomeShowsIt() async {
    let store = TestStore(initialState: ShelfFeature.State()) { ShelfFeature() }
    await store.send(.view(.onAppear)) { $0.now = testNow }
    let summary = store.state.summary
    // 16 seeded objects: 13 owned and kept, of which 12 enamel pins count as 12.
    #expect(summary.count == 24)
    #expect(summary.value == nil)
    #expect(summary.collections.map(\.name) == ["The Library", "My Music", "Board games", "Things"])
    #expect(summary.wanted == 1)
    #expect(summary.today.lines == [.toTidy(2)])
    #expect(!store.state.isEmpty)
  }

  @Test func aCollectionTileOpensTheCollection() async throws {
    let store = TestStore(initialState: ShelfFeature.State()) { ShelfFeature() }
    let id = try #require(store.state.summary.collections.first?.id)
    await store.send(.view(.collectionTapped(id)))
    await store.receive(\.delegate.open, Route.collection(id))
  }

  /// Journey 5's start: a due battery is one line in the Today strip, and it opens the signal feed.
  @Test func aDueBatteryNeedsAttentionAndTheLineOpensTheFeed() async throws {
    _ = try dueCartridge()
    let store = TestStore(initialState: ShelfFeature.State()) { ShelfFeature() }
    await store.send(.view(.onAppear)) { $0.now = testNow }
    try await store.state.$snapshot.load()
    #expect(store.state.summary.today.lines == [.toTidy(2), .needAttention(1)])
    await store.send(.view(.needAttentionTapped))
    await store.receive(\.delegate.open, Route.signals)
  }

  /// F15: the offer shows once a clocked object is on the shelf; accepting asks the system, then schedules each
  /// signal's next change, and the offer is gone.
  @Test func acceptingTheOfferSchedulesTheClocks() async throws {
    let due = try dueCartridge()
    let log = NotificationLog()
    let store = TestStore(initialState: ShelfFeature.State()) {
      ShelfFeature()
    } withDependencies: {
      $0.notifications = .recording(into: log)
    }
    try await store.state.$snapshot.load()
    #expect(store.state.offersNotifications)
    await store.send(.view(.notificationsAccepted))
    await store.finish()
    try await store.state.$snapshot.load()
    #expect(!store.state.offersNotifications)
    let scheduled = try #require(log.replacements.first)
    let link = try #require(scheduled.first { $0.id.contains(due.description) })
    #expect(link.title == "Link's Awakening")
    #expect(link.at == Calendar.testUTC.date(from: DateComponents(year: 2029, month: 1, day: 1)))
    // From then on, each time the shelf appears, the schedule follows the signals.
    await store.send(.view(.onAppear)) { $0.now = testNow }
    await store.finish()
    #expect(log.replacements.count == 2)
  }

  @Test func decliningPutsTheOfferAwayAndSchedulesNothing() async throws {
    _ = try dueCartridge()
    let log = NotificationLog()
    let store = TestStore(initialState: ShelfFeature.State()) {
      ShelfFeature()
    } withDependencies: {
      $0.notifications = .recording(into: log)
    }
    await store.send(.view(.notificationsDeclined))
    await store.finish()
    try await store.state.$snapshot.load()
    #expect(!store.state.offersNotifications)
    await store.send(.view(.onAppear)) { $0.now = testNow }
    #expect(log.replacements.isEmpty)
  }

  @Test func withoutPermissionNothingIsScheduled() async throws {
    _ = try dueCartridge()
    let log = NotificationLog()
    let store = TestStore(initialState: ShelfFeature.State()) {
      ShelfFeature()
    } withDependencies: {
      $0.notifications = .recording(granted: false, into: log)
    }
    await store.send(.view(.notificationsAccepted))
    await store.finish()
    #expect(log.replacements.isEmpty)
  }

  @Test func typeItAsksForTheAddSheet() async {
    let store = TestStore(initialState: ShelfFeature.State()) { ShelfFeature() }
    await store.send(.view(.typeItTapped))
    await store.receive(\.delegate.addByHand)
  }
}

@MainActor
@Suite(.dependencies { try $0.seededShelf(seed: false) })
struct EmptyShelfFeatureTests {
  @Test func anEmptyShelfShowsTheEmptyState() {
    let store = TestStore(initialState: ShelfFeature.State()) { ShelfFeature() }
    #expect(store.state.isEmpty)
    #expect(store.state.summary.today.lines.isEmpty)
    // No clocked object, no offer.
    #expect(!store.state.offersNotifications)
  }
}

import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import ShelfFeature

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct ShelfFeatureTests {
  @Test func theSeedReadsAsTheShelfHomeShowsIt() async {
    let store = TestStore(initialState: ShelfFeature.State()) { ShelfFeature() }
    await store.send(.view(.onAppear)) { $0.now = testNow }
    let summary = store.state.summary
    // 105 seeded objects (M4 grew it): 102 owned and kept, of which 12 enamel pins count as 12.
    #expect(summary.count == 113)
    #expect(summary.value == nil)
    #expect(
      summary.collections.map(\.name) == [
        "The Library", "My Music", "Board games", "Things", "Carts & discs", "Record crates", "Game night",
        "Odds and ends",
      ]
    )
    #expect(summary.wanted == 1)
    // Journey 5's line: the seed's Tetris needs attention.
    #expect(summary.today.lines == [.toTidy(2), .needAttention(1)])
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
    // The seed's Tetris, and this one.
    #expect(store.state.summary.today.lines == [.toTidy(2), .needAttention(2)])
    await store.send(.view(.needAttentionTapped))
    await store.receive(\.delegate.open, Route.signals)
  }

  /// F16: the dashed wishlist tile opens the wishlist.
  @Test func theWishlistTileOpensTheWishlist() async {
    let store = TestStore(initialState: ShelfFeature.State()) { ShelfFeature() }
    await store.send(.view(.wishlistTapped))
    await store.receive(\.delegate.open, Route.wishlist)
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
    // From then on, each time the shelf appears, the schedule follows the signals: a swap moves it 25 years on.
    @Dependency(\.shelf) var shelf
    _ = try shelf.perform(.logEvent(due, kind: ShelfEvent.Kind.servicedKind, note: ""))
    try await store.state.$snapshot.load()
    await store.send(.view(.onAppear)) { $0.now = testNow }
    await store.finish()
    #expect(log.replacements.count == 2)
    let moved = try #require(log.replacements.last?.first { $0.id.contains(due.description) })
    let day = Calendar.testUTC.dateComponents([.year, .month, .day], from: moved.at)
    #expect([day.year, day.month, day.day] == [2052, 1, 15])
  }

  /// F13, T7.8: a loan with a due date brings the offer on its own; accepting schedules its reminder, and a return
  /// takes it away the next time the shelf appears.
  @Test func aLoanWithADateGetsOneReminder() async throws {
    @Dependency(\.shelf) var shelf
    @Dependency(\.defaultDatabase) var database
    let before = try await database.read { db in try ShelfRequest().fetch(db).shelf }
    let homogenic = try #require(before.objects.values.first { $0.title == "Homogenic" }?.id)
    let due = testNow + 14 * 86_400
    _ = try shelf.perform(.lend(homogenic, to: .new(name: "Dara"), due: due, note: ""))
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
    let reminder = try #require(log.loanReplacements.first?.first)
    #expect(reminder.id.hasPrefix(NotificationsClient.loanPrefix))
    #expect(reminder.title == "Homogenic")
    #expect(reminder.body == "Due back from Dara today.")
    #expect(reminder.at == due)

    let lent = try await database.read { db in try ShelfRequest().fetch(db).shelf }
    let loan = try #require(lent.openLoan(on: homogenic))
    _ = try shelf.perform(.returnLoan(loan.id, condition: nil))
    try await store.state.$snapshot.load()
    await store.send(.view(.onAppear)) { $0.now = testNow }
    await store.finish()
    #expect(log.loanReplacements.last == [])
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

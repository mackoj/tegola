import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
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
  }
}

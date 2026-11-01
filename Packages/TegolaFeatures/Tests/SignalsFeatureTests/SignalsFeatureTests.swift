import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import SignalsFeature

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct SignalsFeatureTests {
  /// Journey 5's middle: the feed lists the cartridge whose battery is due, with its reason, and opens it.
  @Test func theFeedListsWhatNeedsAttentionAndOpensIt() async throws {
    let id = try dueCartridge()
    let store = TestStore(initialState: SignalsFeature.State()) { SignalsFeature() }
    try await store.state.$snapshot.load()
    #expect(store.state.feed.map(\.object.id) == [id])
    #expect(store.state.feed.first?.signal.clock == "saveBattery")
    await store.send(.view(.objectTapped(id)))
    await store.receive(\.delegate.open, .object(id))
  }

  @Test func actComesBeforeWatch() async throws {
    let watch = try dueCartridge()
    @Dependency(\.shelf) var shelf
    let act = try dueCartridge("Tetris")
    _ = try shelf.perform(.edit(act, values: [.year: .year(1989)]))
    let store = TestStore(initialState: SignalsFeature.State()) { SignalsFeature() }
    try await store.state.$snapshot.load()
    #expect(store.state.feed.map(\.object.id) == [act, watch])
  }
}

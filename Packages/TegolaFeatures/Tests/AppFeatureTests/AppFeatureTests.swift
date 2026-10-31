import CollectionFeature
import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import ShelfFeature
import TegolaModel
import Testing

@testable import AppFeature

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct AppFeatureTests {
  @Test func tappingATabSelectsIt() async {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(.view(.tabTapped(.find))) { $0.selectedTab = .find }
    await store.send(.view(.tabTapped(.you))) { $0.selectedTab = .you }
  }

  /// PD-117: the middle slot presents, it never becomes the selected tab.
  @Test func scanPresentsInsteadOfSelecting() async {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(.view(.tabTapped(.scan))) { $0.isCapturePresented = true }
    await store.send(.view(.captureDismissed)) { $0.isCapturePresented = false }
  }

  /// PLAN §5: a child asks for a screen with a route, and only the root pushes it.
  @Test func aCollectionRouteIsPushedOntoTheShelfStack() async throws {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    let id = try #require(store.state.shelf.summary.collections.first?.id)
    await store.send(\.shelf.view, .collectionTapped(id))
    await store.receive(\.shelf.delegate.open, .collection(id)) {
      $0.shelfPath[id: 0] = .collection(CollectionFeature.State(id: id))
    }
    // Tapping the Shelf tab while on it goes back to its root.
    await store.send(.view(.tabTapped(.shelf))) { $0.shelfPath.removeAll() }
  }

  @Test func typeItOnTheEmptyShelfOpensTheAddSheet() async {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(\.shelf.view, .typeItTapped)
    await store.receive(\.shelf.delegate.addByHand) { $0.isCapturePresented = true }
  }
}

import ActivityFeature
import AddByHandFeature
import CaptureFeature
import CollectionFeature
import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import FirstPieceFeature
import Foundation
import ObjectFeature
import PersonFeature
import ShelfFeature
import SignalsFeature
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import AppFeature

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct AppFeatureTests {
  /// A shelf with objects never opens on the first piece.
  @Test func aShelfWithObjectsOpensOnTheShelf() async {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(.view(.onAppear))
  }

  @Test func tappingATabSelectsIt() async {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(.view(.tabTapped(.find))) { $0.selectedTab = .find }
    await store.send(.view(.tabTapped(.you))) { $0.selectedTab = .you }
  }

  /// PD-117: the middle slot presents, it never becomes the selected tab.
  @Test func scanPresentsInsteadOfSelecting() async {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(.view(.tabTapped(.scan))) { $0.capture = CaptureFeature.State() }
    #expect(store.state.selectedTab == .shelf)
    await store.send(\.capture.dismiss) { $0.capture = nil }
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

  /// F13: a person's page is a route like any other, and its loans open their objects on the same stack.
  @Test func aPersonsPageIsPushedAndOpensAnObject() async throws {
    var state = AppFeature.State()
    let max = try #require(state.shelf.snapshot.shelf.persons.values.first { $0.name == "Max" }?.id)
    let kidA = try #require(state.shelf.snapshot.shelf.objects.values.first { $0.title == "Kid A" }?.id)
    AppFeature.push(.person(max), onto: &state.shelfPath)
    #expect(state.shelfPath.last == .person(PersonFeature.State(id: max)))
    let store = TestStore(initialState: state) { AppFeature() }
    await store.send(\.shelfPath[id: 0].person.view, .loanTapped(kidA))
    await store.receive(\.shelfPath[id: 0].person.delegate.open, .object(kidA)) {
      $0.shelfPath[id: 1] = .object(ObjectFeature.State(id: kidA))
    }
  }

  /// F13: the Today strip's *N overdue* opens Activity, whose rows push onto its own stack.
  @Test func overdueOpensActivityAndItsRowsPushThere() async throws {
    @Dependency(\.shelf) var shelf
    let homogenic = try #require(
      AppFeature.State().shelf.snapshot.shelf.objects.values.first { $0.title == "Homogenic" }?.id
    )
    _ = try shelf.perform(.lend(homogenic, to: .new(name: "Dara"), due: testNow - 86_400, note: ""))
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(\.shelf.view, .overdueTapped)
    await store.receive(\.shelf.delegate.showActivity) { $0.selectedTab = .activity }
    await store.send(\.activity.view, .objectTapped(homogenic))
    await store.receive(\.activity.delegate.open, .object(homogenic)) {
      $0.activityPath[id: 0] = .object(ObjectFeature.State(id: homogenic))
    }
    await store.send(.view(.tabTapped(.activity))) { $0.activityPath.removeAll() }
  }

  @Test func theSignalFeedIsPushedAndOpensAnObject() async throws {
    let id = try dueCartridge()
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(\.shelf.view, .needAttentionTapped)
    await store.receive(\.shelf.delegate.open, .signals) {
      $0.shelfPath[id: 0] = .signals(SignalsFeature.State())
    }
    await store.send(\.shelfPath[id: 0].signals.view, .objectTapped(id))
    await store.receive(\.shelfPath[id: 0].signals.delegate.open, .object(id)) {
      $0.shelfPath[id: 1] = .object(ObjectFeature.State(id: id))
    }
  }

  @Test func typeItOnTheEmptyShelfOpensTheAddSheet() async {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(\.shelf.view, .typeItTapped)
    await store.receive(\.shelf.delegate.addByHand) { $0.addByHand = AddByHandFeature.State() }
  }
}

/// PLAN F2: the app opens on the first piece while the shelf is empty and it hasn't been skipped.
@MainActor
@Suite(.dependencies { try $0.seededShelf(seed: false) })
struct AppFirstPieceTests {
  @Test func anEmptyShelfOpensOnTheFirstPiece() async {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(.view(.onAppear)) { $0.firstPiece = FirstPieceFeature.State() }
    await store.send(\.firstPiece.presented.view, .lookAroundTapped)
    await store.receive(\.firstPiece.presented.delegate.skipped) { $0.firstPiece = nil }
    // Skipped: the next launch opens on the empty shelf, which offers the camera again.
    let next = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await next.send(.view(.onAppear))
    await next.send(\.shelf.view, .scanFirstObjectTapped)
    await next.receive(\.shelf.delegate.scanFirstObject) { $0.firstPiece = FirstPieceFeature.State() }
  }

  /// **One at a time**: the next piece goes through Scan.
  @Test func oneAtATimeOpensScan() async {
    var state = AppFeature.State()
    state.firstPiece = FirstPieceFeature.State()
    let clock = TestClock()
    let store = TestStore(initialState: state) {
      AppFeature()
    } withDependencies: {
      $0.continuousClock = clock
    }
    await store.send(\.firstPiece.presented.view, .oneAtATimeTapped)
    await store.receive(\.firstPiece.presented.delegate.oneAtATime) { $0.firstPiece = nil }
    // Scan waits for the cover to go.
    await clock.advance(by: .milliseconds(600))
    await store.receive(\.presentScan) { $0.capture = CaptureFeature.State() }
  }
}

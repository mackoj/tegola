import ComposableArchitecture
import Testing

@testable import AppFeature

@MainActor
@Suite struct AppFeatureTests {
  @Test func tappingATabSelectsIt() async {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(.view(.tabTapped(.find))) { $0.selectedTab = .find }
    await store.send(.view(.tabTapped(.you))) { $0.selectedTab = .you }
  }

  /// PD-117: the middle slot presents the camera, it never becomes the selected tab.
  @Test func scanPresentsInsteadOfSelecting() async {
    let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
    await store.send(.view(.tabTapped(.scan))) { $0.isCapturePresented = true }
    await store.send(.view(.captureDismissed)) { $0.isCapturePresented = false }
  }
}

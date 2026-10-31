#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaSnapshotTesting
  import Testing

  @testable import FindFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct FindSnapshotTests {
    @Test func savedViews() {
      let store = Store(initialState: FindFeature.State()) { FindFeature() }
      assertScreenSnapshot(of: FindView(store: store), named: "savedViews", suite: "find", height: 852)
    }

    @Test func results() {
      let store = Store(initialState: FindFeature.State()) { FindFeature() }
      store.send(.view(.textChanged("office")))
      assertScreenSnapshot(of: FindView(store: store), named: "results", suite: "find", height: 852)
    }
  }
#endif

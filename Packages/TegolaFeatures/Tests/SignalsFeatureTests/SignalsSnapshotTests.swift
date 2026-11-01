#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaSnapshotTesting
  import Testing

  @testable import SignalsFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct SignalsSnapshotTests {
    @Test func feed() throws {
      _ = try dueCartridge()
      let store = Store(initialState: SignalsFeature.State()) { SignalsFeature() }
      assertScreenSnapshot(of: SignalsView(store: store), named: "feed", suite: "signals", height: 900)
    }
  }
#endif

#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaCatalogue
  import TegolaModel
  import TegolaSnapshotTesting
  import Testing

  @testable import AddByHandFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct AddByHandSnapshotTests {
    @Test func typePicker() {
      let store = Store(initialState: AddByHandFeature.State()) { AddByHandFeature() }
      assertScreenSnapshot(of: AddByHandView(store: store), named: "typePicker", suite: "add", height: 852)
    }

    @Test func boardGameForm() {
      let store = Store(initialState: AddByHandFeature.State()) { AddByHandFeature() }
      store.send(.view(.typeTapped("board-games")))
      store.send(.view(.valueChanged(.title, .text("Spirit Island"))))
      assertScreenSnapshot(of: AddByHandView(store: store), named: "boardGameForm", suite: "add", height: 1800)
    }
  }
#endif

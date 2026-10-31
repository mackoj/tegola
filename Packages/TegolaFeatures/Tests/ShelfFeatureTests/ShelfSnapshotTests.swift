#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SQLiteData
  import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaModel
  import TegolaSnapshotTesting
  import TegolaStorage
  import Testing

  @testable import ShelfFeature

  /// The Shelf home in the states its previews show (PLAN §2.6), at the iPhone 17 size.
  @MainActor
  @Suite(.serialized)
  struct ShelfSnapshotTests {
    func snapshot(_ name: String) {
      let store = Store(initialState: ShelfFeature.State()) { ShelfFeature() }
      store.send(.view(.onAppear))
      assertScreenSnapshot(of: ShelfView(store: store), named: name, suite: "shelf", height: 852)
    }

    @Test(.dependencies { try $0.seededShelf() })
    func populatedMoneyOff() {
      snapshot("populatedMoneyOff")
    }

    @Test(
      .dependencies {
        try $0.seededShelf()
        try ShelfStore(migrated: $0.defaultDatabase, catalogue: $0.catalogue).set(.money, to: "on")
      }
    )
    func populatedMoneyOn() {
      snapshot("populatedMoneyOn")
    }

    @Test(.dependencies { try $0.seededShelf(seed: false) })
    func empty() {
      snapshot("empty")
    }
  }
#endif

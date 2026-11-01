#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaModel
  import TegolaSnapshotTesting
  import Testing

  @testable import ShareFeature

  @MainActor
  @Suite(
    .serialized,
    .dependencies {
      try $0.seededShelf()
      $0.locale = Locale(identifier: "fr_FR")
    }
  )
  struct ShareSnapshotTests {
    /// The sheet as it opens: the record, with the catalogue's facts only.
    @Test func record() throws {
      let id = try paySilvergun()
      let store = Store(initialState: ShareFeature.State(objectID: id)) { ShareFeature() }
      assertScreenSnapshot(of: ShareView(store: store), named: "record", suite: "share", height: 1300)
    }

    /// My copy with money on: the grades, the asking price, and still nothing paid.
    @Test func myCopyWithAnAskingPrice() throws {
      let id = try paySilvergun()
      try moneyOn()
      var state = ShareFeature.State(objectID: id)
      state.kind = .myCopy
      state.asking = 150
      let store = Store(initialState: state) { ShareFeature() }
      assertScreenSnapshot(of: ShareView(store: store), named: "myCopy", suite: "share", height: 1500)
    }
  }
#endif

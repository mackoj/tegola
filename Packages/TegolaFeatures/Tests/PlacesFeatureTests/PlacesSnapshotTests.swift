#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaModel
  import TegolaSnapshotTesting
  import TegolaStorage
  import Testing

  @testable import PlacesFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct PlacesSnapshotTests {
    @Test func placesWithAMergeOffer() throws {
      @Dependency(\.shelf) var shelf
      let receipt = try shelf.perform(
        .add(
          ObjectDraft(type: "thing", values: [.title: .text("Snow globe")]),
          to: .new(name: "Things"),
          origin: .typed
        )
      )
      _ = try shelf.perform(.setPlace(receipt.createdObjects, PlacePath(typed: "Ofice")))
      let store = Store(initialState: PlacesFeature.State()) { PlacesFeature() }
      assertScreenSnapshot(of: PlacesView(store: store), named: "places", suite: "places", height: 852)
    }
  }
#endif

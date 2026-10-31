#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaSnapshotTesting
  import Testing

  @testable import ObjectFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct ObjectSnapshotTests {
    @Test(arguments: ["Radiant Silvergun", "Kid A", "Enamel pins"])
    func object(_ title: String) throws {
      let id = try seededObject(title)
      let store = Store(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
      assertScreenSnapshot(of: ObjectView(store: store), named: title, suite: "object", height: 1200)
    }
  }
#endif

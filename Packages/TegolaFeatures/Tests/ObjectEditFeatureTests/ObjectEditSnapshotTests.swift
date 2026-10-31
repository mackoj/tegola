#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SQLiteData
  import SwiftUI
  import TegolaModel
  import TegolaSnapshotTesting
  import TegolaStorage
  import Testing

  @testable import ObjectEditFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct ObjectEditSnapshotTests {
    @Test func saturnGame() throws {
      @Dependency(\.defaultDatabase) var database
      let shelf = try database.read { db in try ShelfRequest().fetch(db).shelf }
      let object = try #require(shelf.objects.values.first { $0.title == "Radiant Silvergun" })
      let state = ObjectEditFeature.State(
        object: object,
        placePath: object.placeID.flatMap { shelf.placePath(of: $0) },
        money: .off
      )
      let store = Store(initialState: state) { ObjectEditFeature() }
      assertScreenSnapshot(of: ObjectEditView(store: store), named: "saturnGame", suite: "edit", height: 2400)
    }
  }
#endif

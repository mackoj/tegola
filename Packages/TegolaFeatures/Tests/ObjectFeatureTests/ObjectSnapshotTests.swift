#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaSnapshotTesting
  import Testing

  import TegolaClients
  import TegolaModel
  import UIKit

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

    /// The hero is the collector's photo once there is one (PD-145).
    @Test func withAPhoto() throws {
      @Dependency(\.photoStore) var photoStore
      @Dependency(\.shelf) var shelf
      let id = try seededObject("Tin robot")
      let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300)).jpegData(withCompressionQuality: 0.9) {
        context in
        UIColor.systemTeal.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        UIColor.systemOrange.setFill()
        context.cgContext.fillEllipse(in: CGRect(x: 80, y: 80, width: 140, height: 140))
      }
      let name = try photoStore.save(image)
      _ = try shelf.perform(.attachPhoto(id, fileName: name, takenAt: testNow))
      let store = Store(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
      assertScreenSnapshot(of: ObjectView(store: store), named: "withAPhoto", suite: "object", height: 1200)
    }
  }
#endif

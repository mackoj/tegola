#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaSnapshotTesting
  import Testing

  import TegolaClients
  import TegolaModel
  import TegolaStorage
  import SQLiteData
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

    /// F15 on the object screen: a due battery, then after a swap, then dismissed instead.
    @Test func dueBattery() throws {
      let id = try dueCartridge()
      let store = Store(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
      assertScreenSnapshot(of: ObjectView(store: store), named: "dueBattery", suite: "object", height: 1200)
    }

    @Test func afterASwap() throws {
      @Dependency(\.shelf) var shelf
      let id = try dueCartridge()
      _ = try shelf.perform(.logEvent(id, kind: ShelfEvent.Kind.servicedKind, note: ""))
      let store = Store(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
      assertScreenSnapshot(of: ObjectView(store: store), named: "afterASwap", suite: "object", height: 1200)
    }

    @Test func dismissed() throws {
      @Dependency(\.shelf) var shelf
      @Dependency(\.date.now) var now
      let id = try dueCartridge()
      @Dependency(\.defaultDatabase) var database
      let snapshot = try database.read { db in try ShelfRequest().fetch(db) }
      let signal = try #require(snapshot.signals(for: id, at: now).first)
      _ = try shelf.perform(.dismissSignal(id, signal))
      let store = Store(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
      assertScreenSnapshot(of: ObjectView(store: store), named: "dismissed", suite: "object", height: 1200)
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

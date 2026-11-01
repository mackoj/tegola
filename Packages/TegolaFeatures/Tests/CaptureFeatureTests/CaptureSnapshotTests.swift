#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaModel
  import TegolaSnapshotTesting
  import Testing

  @testable import CaptureFeature

  /// The Scan sheet (T6.9). The simulator has no camera, so the scanner shows its placeholder.
  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct CaptureSnapshotTests {
    @Test func addTo() {
      let store = Store(initialState: CaptureFeature.State()) { CaptureFeature() }
      assertScreenSnapshot(of: CaptureView(store: store), named: "addTo", suite: "capture", height: 852)
    }

    @Test func withATray() {
      var state = CaptureFeature.State(type: "video-game")
      state.collection = .new(name: "The Library")
      state.seen = .barcode("045496730437")
      state.identify = true
      state.tray = [
        .init(id: ObjectID(rawValue: UUID(0)), seen: .barcode("045496730437"), status: .proposed("Tetris")),
        .init(id: ObjectID(rawValue: UUID(1)), seen: nil, status: .queued),
        .init(id: ObjectID(rawValue: UUID(2)), seen: .text("ZELDA"), status: .nothingFound),
      ]
      let store = Store(initialState: state) { CaptureFeature() }
      assertScreenSnapshot(of: CaptureView(store: store), named: "tray", suite: "capture", height: 1300)
    }
  }
#endif

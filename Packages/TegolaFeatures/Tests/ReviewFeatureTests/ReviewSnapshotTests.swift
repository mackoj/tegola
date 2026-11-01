#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SQLiteData
  import SwiftUI
  import TegolaClients
  import TegolaModel
  import TegolaSnapshotTesting
  import TegolaStorage
  import Testing

  @testable import ReviewFeature

  /// The review queue (T6.11): a strong match, a question, and the seed's rows as written.
  @MainActor
  @Suite(
    .serialized,
    .dependencies {
      try $0.seededShelf()
      $0.lookupQueue = .store(ShelfStore(migrated: $0.defaultDatabase, catalogue: $0.catalogue))
    }
  )
  struct ReviewSnapshotTests {
    @Test func queue() throws {
      _ = try captured(
        "Ridge Racer",
        answer: [candidate("Ridge Racer", release: "r1", confidence: 0.97, publisher: "Namco")]
      )
      _ = try captured(
        "Tetris",
        answer: [
          candidate("Tetris", release: "gb", confidence: 0.7),
          candidate("Tetris Plus", release: "plus", confidence: 0.65),
        ]
      )
      @Dependency(\.lookupQueue) var queue
      var state = ReviewFeature.State()
      state.queue = try queue.load()
      let store = Store(initialState: state) { ReviewFeature() }
      assertScreenSnapshot(of: ReviewView(store: store), named: "queue", suite: "review", height: 1800)
    }
  }
#endif

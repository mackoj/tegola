#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaClients
  import TegolaModel
  import TegolaSnapshotTesting
  import Testing

  @testable import ActivityFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct ActivitySnapshotTests {
    /// Boards 17 and 22: Homogenic overdue with Dara, Kid A out with Max, a record back from Léa, Root borrowed.
    func lending() throws {
      @Dependency(\.shelf) var shelf
      _ = try lendHomogenicOverdue()
      let nebraska = try object("Nebraska")
      let lea = try #require(try shelfNow().persons.values.first { $0.name == "Léa" }?.id)
      _ = try shelf.perform(.lend(nebraska, to: .existing(lea), due: nil, note: ""))
      let loan = try #require(try shelfNow().openLoan(on: nebraska))
      _ = try shelf.perform(.returnLoan(loan.id, cameBack: .sameShape, condition: nil))
    }

    @Test func outNow() throws {
      try lending()
      let store = Store(initialState: ActivityFeature.State()) { ActivityFeature() }
      assertScreenSnapshot(of: ActivityView(store: store), named: "outNow", suite: "activity", height: 1400)
    }

    @Test func byPerson() throws {
      try lending()
      var state = ActivityFeature.State()
      state.filter = .byPerson
      let store = Store(initialState: state) { ActivityFeature() }
      assertScreenSnapshot(of: ActivityView(store: store), named: "byPerson", suite: "activity", height: 1100)
    }

    @Test func outNowInFrench() throws {
      try lending()
      let store = Store(initialState: ActivityFeature.State()) { ActivityFeature() }
      assertScreenSnapshot(
        of: ActivityView(store: store).environment(\.locale, Locale(identifier: "fr")),
        named: "outNow-fr",
        suite: "activity",
        height: 1400
      )
    }
  }

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf(seed: false) })
  struct ActivityEmptySnapshotTests {
    @Test func empty() {
      let store = Store(initialState: ActivityFeature.State()) { ActivityFeature() }
      assertScreenSnapshot(of: ActivityView(store: store), named: "empty", suite: "activity", height: 800)
    }
  }
#endif

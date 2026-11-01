#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaModel
  import TegolaSnapshotTesting
  import Testing

  @testable import LendFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct LendSnapshotTests {
    func state(_ mode: LendFeature.State.Mode, people: Bool = true) throws -> LendFeature.State {
      let id = try seeded("Homogenic")
      return LendFeature.State(
        objectID: id,
        title: "Homogenic",
        mode: mode,
        people: people ? try shelfNow().recentPeople : [],
        now: testNow
      )
    }

    /// Board 18: a known person picked, two weeks, a note.
    @Test func lend() throws {
      var state = try state(.lend)
      state.person = state.people.last?.id
      state.note = "For the drive to Lyon"
      let store = Store(initialState: state) { LendFeature() }
      assertScreenSnapshot(of: LendView(store: store), named: "lend", suite: "lending", height: 1100)
    }

    /// The first loan ever: nobody to pick, so the name field is open.
    @Test func lendToSomeoneNew() throws {
      var state = try state(.lend, people: false)
      state.newName = "Dara"
      state.due = .date
      let store = Store(initialState: state) { LendFeature() }
      assertScreenSnapshot(of: LendView(store: store), named: "lendNew", suite: "lending", height: 1100)
    }

    @Test func whoseIsIt() throws {
      let initial = try state(.borrow)
      let store = Store(initialState: initial) { LendFeature() }
      assertScreenSnapshot(of: LendView(store: store), named: "whoseIsIt", suite: "lending", height: 1100)
    }

    @Test func lendInFrench() throws {
      var state = try state(.lend)
      state.person = state.people.first?.id
      let store = Store(initialState: state) { LendFeature() }
      assertScreenSnapshot(
        of: LendView(store: store).environment(\.locale, Locale(identifier: "fr")),
        named: "lend.fr",
        suite: "lending",
        height: 1100
      )
    }
  }
#endif

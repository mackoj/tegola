#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaModel
  import TegolaSnapshotTesting
  import Testing

  @testable import ReturnFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct ReturnSnapshotTests {
    /// Board 20: late, damaged, with a note, and what gets written.
    @Test func overdueAndDamaged() throws {
      var state = ReturnFeature.State(
        loanID: LoanID(UUID()),
        nudge: Nudge(title: "Awesome Mix Vol. 1", person: "Elsa", daysOut: 192, daysOverdue: 14)
      )
      state.cameBack = .damaged
      state.note = "Six months. Worth it."
      let store = Store(initialState: state) { ReturnFeature() }
      assertScreenSnapshot(of: ReturnView(store: store), named: "overdueDamaged", suite: "lending", height: 1100)
    }

    @Test func onTimeInFrench() throws {
      let state = ReturnFeature.State(
        loanID: LoanID(UUID()),
        nudge: Nudge(title: "Kid A", person: "Max", daysOut: 9, daysOverdue: nil)
      )
      let store = Store(initialState: state) { ReturnFeature() }
      assertScreenSnapshot(
        of: ReturnView(store: store).environment(\.locale, Locale(identifier: "fr")),
        named: "onTime.fr",
        suite: "lending",
        height: 1100
      )
    }
  }
#endif

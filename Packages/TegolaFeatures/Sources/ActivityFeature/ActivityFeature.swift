public import ComposableArchitecture
public import Foundation
public import ReturnFeature
public import SQLiteData
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// The Activity tab (F13, boards 17 and 22): loans out with overdue first, what came back, who holds what, and
/// someone else's objects on the shelf. It's the only tab with a badge: the overdue loans (`Activity.badge`).
@Reducer
public struct ActivityFeature {
  @ObservableState
  public struct State: Equatable {
    /// Board 17's pills.
    public enum Filter: Hashable, Sendable, CaseIterable {
      case outNow, returned, byPerson
    }

    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    public var filter: Filter = .outNow
    @Presents public var returnLoan: ReturnFeature.State?

    public init() {}

    public var activity: Activity {
      @Dependency(\.date.now) var now
      return Activity(shelf: snapshot.shelf, now: now)
    }

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.filter == rhs.filter && lhs.returnLoan == rhs.returnLoan
    }
  }

  public enum Action: ViewAction {
    case delegate(Delegate)
    case returnLoan(PresentationAction<ReturnFeature.Action>)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      case open(Route)
    }

    public enum View: Equatable {
      case filterTapped(State.Filter)
      case markReturnedTapped(LoanID)
      case objectTapped(ObjectID)
      case personTapped(PersonID)
    }
  }

  @Dependency(\.calendar) var calendar
  @Dependency(\.date.now) var now

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate, .returnLoan:
        return .none
      case .view(.filterTapped(let filter)):
        state.filter = filter
        return .none
      case .view(.markReturnedTapped(let id)):
        state.returnLoan = ReturnFeature.State(loan: id, shelf: state.snapshot.shelf, now: now, calendar: calendar)
        return .none
      case .view(.objectTapped(let id)):
        return .send(.delegate(.open(.object(id))))
      case .view(.personTapped(let id)):
        return .send(.delegate(.open(.person(id))))
      }
    }
    .ifLet(\.$returnLoan, action: \.returnLoan) { ReturnFeature() }
  }
}

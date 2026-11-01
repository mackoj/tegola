public import ComposableArchitecture
import Foundation
public import SQLiteData
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// The signal feed (F15, journey 5): every signal that needs attention, most urgent first, each with its reason. The
/// Today strip's "need attention" line opens it, and each row opens its object.
@Reducer
public struct SignalsFeature {
  @ObservableState
  public struct State: Equatable {
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()

    public init() {}

    /// The feed now: the object and the signal, act before watch, then soonest to change.
    public var feed: [(object: ShelfObject, signal: Signal)] {
      @Dependency(\.date.now) var now
      let shelf = snapshot.shelf
      return snapshot.signals(at: now).feed.compactMap { entry in
        shelf.objects[entry.object].map { (object: $0, signal: entry.signal) }
      }
    }

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool { true }
  }

  public enum Action: ViewAction {
    case delegate(Delegate)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      case open(Route)
    }

    public enum View: Equatable {
      case objectTapped(ObjectID)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case .delegate:
        return .none
      case .view(.objectTapped(let id)):
        return .send(.delegate(.open(.object(id))))
      }
    }
  }
}

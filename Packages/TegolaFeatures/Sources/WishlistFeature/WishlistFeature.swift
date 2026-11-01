public import ComposableArchitecture
public import Foundation
public import SQLiteData
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// The wishlist (F16): wanted objects, grails first, with **It arrived** (ownership flips, history stays), **Grail**,
/// the price cap only with money on, and **Share the list**, a card of wants that never shows holdings (PD-071).
@Reducer
public struct WishlistFeature {
  @ObservableState
  public struct State: Equatable {
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()

    public init() {}

    public var wishlist: Wishlist { Wishlist(shelf: snapshot.shelf, money: snapshot.money) }

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
      case arrivedTapped(ObjectID)
      case grailTapped(ObjectID)
      case wantTapped(ObjectID)
    }
  }

  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none
      case .view(.arrivedTapped(let id)):
        return .run { [shelf] _ in
          _ = try shelf.perform(.setOwned(id))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.grailTapped(let id)):
        let isGrail = state.snapshot.shelf.objects[id]?.isGrail ?? false
        return .run { [shelf] _ in
          _ = try shelf.perform(.setGrail(id, !isGrail))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.wantTapped(let id)):
        return .send(.delegate(.open(.object(id))))
      }
    }
  }
}

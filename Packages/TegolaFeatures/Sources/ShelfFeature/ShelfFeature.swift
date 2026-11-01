public import ComposableArchitecture
public import Foundation
public import SQLiteData
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// The Shelf home (F3, board 01): the count, the Today strip, the collections as tiles, the wishlist, and the empty
/// shelf (board 02) before the first object. It reads the shelf through one query and asks for screens by route.
@Reducer
public struct ShelfFeature {
  @ObservableState
  public struct State: Equatable {
    /// The projection and the money setting, kept current by the database.
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    /// When the screen last appeared: the Today strip's "now" (overdue is relative to it).
    public var now: Date

    public init(now: Date = .distantPast) {
      self.now = now
    }

    public var summary: ShelfSummary {
      ShelfSummary(
        shelf: snapshot.shelf,
        money: snapshot.money,
        now: now,
        statuses: snapshot.signals(at: now).statuses
      )
    }

    /// Nothing on the shelf at all, wanted objects included: the empty state (board 02).
    public var isEmpty: Bool { snapshot.shelf.objects.isEmpty }

    /// The reducer's own state. The snapshot is the database's, kept current outside any action, so tests assert on
    /// it directly rather than through exhaustive state comparison.
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.now == rhs.now
    }
  }

  public enum Action: ViewAction {
    case delegate(Delegate)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      /// Add an object by hand (the Scan sheet's Type it).
      case addByHand
      case open(Route)
    }

    public enum View: Equatable {
      case collectionTapped(CollectionID)
      case needAttentionTapped
      case onAppear
      case placesTapped
      case typeItTapped
    }
  }

  @Dependency(\.date.now) var now

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none
      case .view(.collectionTapped(let id)):
        return .send(.delegate(.open(.collection(id))))
      case .view(.needAttentionTapped):
        return .send(.delegate(.open(.signals)))
      case .view(.onAppear):
        state.now = now
        return .none
      case .view(.placesTapped):
        return .send(.delegate(.open(.places)))
      case .view(.typeItTapped):
        return .send(.delegate(.addByHand))
      }
    }
  }
}

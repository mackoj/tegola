public import ComposableArchitecture
import Foundation
public import SQLiteData
public import TegolaCatalogue
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// Find (F11, board 07): search over every field, note and entry, with filters that stack as chips and saved views
/// that are live queries. Each result says what matched.
@Reducer
public struct FindFeature {
  @ObservableState
  public struct State: Equatable {
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    public var query = SearchQuery()

    public init() {}

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.query == rhs.query }
  }

  public enum Action: ViewAction {
    case delegate(Delegate)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      case open(Route)
    }

    public enum View: Equatable {
      case archiveTapped
      case clearTapped
      case lentOutTapped
      case resultTapped(ObjectID)
      case textChanged(String)
      case typeTapped(TypeManifest.ID)
      case viewTapped(SavedView?)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none
      case .view(.archiveTapped):
        state.query.includeArchive.toggle()
        return .none
      case .view(.clearTapped):
        state.query = SearchQuery()
        return .none
      case .view(.lentOutTapped):
        state.query.lentOut.toggle()
        return .none
      case .view(.resultTapped(let id)):
        return .send(.delegate(.open(.object(id))))
      case .view(.textChanged(let text)):
        state.query.text = text
        return .none
      case .view(.typeTapped(let type)):
        if state.query.types.contains(type) {
          state.query.types.remove(type)
        } else {
          state.query.types.insert(type)
        }
        return .none
      case .view(.viewTapped(let view)):
        state.query.view = view
        return .none
      }
    }
  }
}

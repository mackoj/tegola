public import ComposableArchitecture
import Foundation
public import SQLiteData
import TegolaCatalogue
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// One object as a display case (F4, board 04 under PD-013): seven slots in a fixed order (hero, spine, status,
/// signature, fields, actions, history), and controls only as actions. M3's actions are Edit, Photo and Might let go;
/// Lend, Return and Let go join with their sheets (D-48).
@Reducer
public struct ObjectFeature {
  @ObservableState
  public struct State: Equatable {
    public let id: ObjectID
    @ObservationStateIgnored
    @Fetch public var snapshot: ObjectSnapshot

    public init(id: ObjectID) {
      self.id = id
      self._snapshot = Fetch(wrappedValue: ObjectSnapshot(), ObjectRequest(id: id))
    }

    public var object: ShelfObject? { snapshot.shelf.shelf.objects[id] }

    /// The History slot: the kinds a person reads, newest first (board 36).
    public var history: [ShelfEvent] {
      snapshot.history.filter(\.kind.readsAsHistory).reversed()
    }

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
  }

  public enum Action: ViewAction {
    case delegate(Delegate)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      case edit(ObjectID)
      case photo(ObjectID)
    }

    public enum View: Equatable {
      case editTapped
      case mightLetGoTapped
      case photoTapped
    }
  }

  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none
      case .view(.editTapped):
        return .send(.delegate(.edit(state.id)))
      case .view(.mightLetGoTapped):
        guard let object = state.object else { return .none }
        let id = state.id
        return .run { [shelf] _ in
          _ = try shelf.perform(.setMightLetGo(id, !object.mightLetGo))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.photoTapped):
        return .send(.delegate(.photo(state.id)))
      }
    }
  }
}

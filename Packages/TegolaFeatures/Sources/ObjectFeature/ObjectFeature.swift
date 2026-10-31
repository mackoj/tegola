public import ComposableArchitecture
public import Foundation
public import ObjectEditFeature
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
    @Presents public var edit: ObjectEditFeature.State?
    /// The photo picker is open.
    public var isPickingPhoto = false

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
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id && lhs.edit == rhs.edit && lhs.isPickingPhoto == rhs.isPickingPhoto
    }
  }

  public enum Action: ViewAction {
    case edit(PresentationAction<ObjectEditFeature.Action>)
    case view(View)

    public enum View: Equatable {
      case editTapped
      case mightLetGoTapped
      case photoPicked(Data)
      case photoPickerDismissed
      case photoTapped
    }
  }

  @Dependency(\.date.now) var now
  @Dependency(\.photoStore) var photoStore
  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .edit:
        return .none
      case .view(.editTapped):
        guard let object = state.object else { return .none }
        let shelf = state.snapshot.shelf.shelf
        let path = object.placeID.flatMap { shelf.placePath(of: $0) }
        state.edit = ObjectEditFeature.State(object: object, placePath: path, money: state.snapshot.shelf.money)
        return .none
      case .view(.mightLetGoTapped):
        guard let object = state.object else { return .none }
        let id = state.id
        return .run { [shelf] _ in
          _ = try shelf.perform(.setMightLetGo(id, !object.mightLetGo))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.photoPicked(let data)):
        state.isPickingPhoto = false
        let id = state.id
        return .run { [photoStore, shelf, now] _ in
          let fileName = try photoStore.save(data)
          _ = try shelf.perform(.attachPhoto(id, fileName: fileName, takenAt: now))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.photoPickerDismissed):
        state.isPickingPhoto = false
        return .none
      case .view(.photoTapped):
        state.isPickingPhoto = true
        return .none
      }
    }
    .ifLet(\.$edit, action: \.edit) { ObjectEditFeature() }
  }
}

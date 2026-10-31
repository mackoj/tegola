public import ComposableArchitecture
import Foundation
public import SQLiteData
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// One collection (F4, board 03): its objects as rows, the mono meta line, sorting, a place filter, rename. A mixed
/// collection groups its rows by type. Filtering by status waits for statuses (M4).
@Reducer
public struct CollectionFeature {
  @ObservableState
  public struct State: Equatable {
    public let id: CollectionID
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    public var sort: Sort = .recent
    public var place: PlaceID?
    /// The rename sheet's draft, while it's open. Cancel writes nothing; Save sends one command.
    public var renameDraft: String?

    public init(id: CollectionID) {
      self.id = id
    }

    public var collection: ShelfCollection? { snapshot.shelf.collections[id] }

    /// The rows, sorted and filtered. A let-go object leaves the collection's list for the archive (F16).
    public var objects: [ShelfObject] {
      let shelf = snapshot.shelf
      let places = place.map { shelf.placeAndInside($0) }
      let members = shelf.objects.values.filter { object in
        object.collectionID == id && object.letGo == nil
          && (places.map { object.placeID.map($0.contains) ?? false } ?? true)
      }
      return members.sorted(by: sort.areInIncreasingOrder)
    }

    /// The places objects here sit in: the filter's choices, once there are two.
    public var placeChoices: [Place] {
      let used = Set(
        snapshot.shelf.objects.values.filter { $0.collectionID == id && $0.letGo == nil }.compactMap(\.placeID)
      )
      let places = used.compactMap { snapshot.shelf.places[$0] }.sorted { $0.name < $1.name }
      return places.count >= 2 ? places : []
    }

    /// The reducer's own state. The snapshot is the database's, kept current outside any action, so tests assert on
    /// it directly rather than through exhaustive state comparison.
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id && lhs.sort == rhs.sort && lhs.place == rhs.place && lhs.renameDraft == rhs.renameDraft
    }
  }

  public enum Sort: String, CaseIterable, Equatable, Sendable {
    case recent, title, year

    func areInIncreasingOrder(_ a: ShelfObject, _ b: ShelfObject) -> Bool {
      switch self {
      case .recent:
        return (a.createdAt, b.id) > (b.createdAt, a.id)
      case .title:
        return (a.title.localizedLowercase, a.id) < (b.title.localizedLowercase, b.id)
      case .year:
        func year(_ o: ShelfObject) -> Int { if case .year(let y) = o.values[.year] { y } else { Int.max } }
        return (year(a), a.title, a.id) < (year(b), b.title, b.id)
      }
    }
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
      case placeTapped(PlaceID?)
      case renameCancelTapped
      case renameChanged(String)
      case renameSaveTapped
      case renameTapped
      case sortTapped(Sort)
    }
  }

  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none
      case .view(.objectTapped(let id)):
        return .send(.delegate(.open(.object(id))))
      case .view(.placeTapped(let place)):
        state.place = place
        return .none
      case .view(.renameCancelTapped):
        state.renameDraft = nil
        return .none
      case .view(.renameChanged(let name)):
        state.renameDraft = name
        return .none
      case .view(.renameSaveTapped):
        guard let name = state.renameDraft else { return .none }
        state.renameDraft = nil
        let id = state.id
        return .run { [shelf] _ in
          _ = try shelf.perform(.renameCollection(id, name: name))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.renameTapped):
        state.renameDraft = state.collection?.name ?? ""
        return .none
      case .view(.sortTapped(let sort)):
        state.sort = sort
        return .none
      }
    }
  }
}

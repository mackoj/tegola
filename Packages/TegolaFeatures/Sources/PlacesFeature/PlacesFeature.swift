public import ComposableArchitecture
import Foundation
public import SQLiteData
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// Places (F10): every top-level place with what it holds, and a one-tap merge for names that look like the same
/// place typed twice. It appears once two places exist; unplaced is never a warning.
@Reducer
public struct PlacesFeature {
  @ObservableState
  public struct State: Equatable {
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()

    public init() {}

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
      case mergeTapped(PlaceID, into: PlaceID)
      case placeTapped(PlaceID)
    }
  }

  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case .delegate:
        return .none
      case .view(.mergeTapped(let from, let into)):
        return .run { [shelf] _ in
          _ = try shelf.perform(.mergePlaces(from, into: into))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.placeTapped(let id)):
        return .send(.delegate(.open(.place(id))))
      }
    }
  }
}

/// One place (F10): what's in it and in the places inside it, whatever their type.
@Reducer
public struct PlaceFeature {
  @ObservableState
  public struct State: Equatable {
    public let id: PlaceID
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()

    public init(id: PlaceID) {
      self.id = id
    }

    /// Objects here or in a place inside, let-go ones excluded.
    public var objects: [ShelfObject] {
      let inside = snapshot.shelf.placeAndInside(id)
      return snapshot.shelf.objects.values
        .filter { object in object.letGo == nil && (object.placeID.map(inside.contains) ?? false) }
        .sorted { ($0.title.localizedLowercase, $0.id) < ($1.title.localizedLowercase, $1.id) }
    }

    public var children: [Place] {
      snapshot.shelf.livePlaces.filter { $0.parentID == id }.sorted { $0.name < $1.name }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
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
      case placeTapped(PlaceID)
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
      case .view(.placeTapped(let id)):
        return .send(.delegate(.open(.place(id))))
      }
    }
  }
}

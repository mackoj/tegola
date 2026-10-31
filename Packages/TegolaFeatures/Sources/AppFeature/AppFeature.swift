public import AddByHandFeature
public import CollectionFeature
public import ComposableArchitecture
public import FindFeature
public import ObjectFeature
public import PlacesFeature
public import ShelfFeature
public import TegolaModel

/// Every screen a tab's stack can push (PLAN §5). One enum for every tab, defined here: only the root pushes.
@Reducer
public enum AppPath {
  case collection(CollectionFeature)
  case object(ObjectFeature)
  case place(PlaceFeature)
  case places(PlacesFeature)
}

extension AppPath.State: Equatable {}

/// The root: the tab bar and one navigation stack per tab (PLAN §5). Children ask for screens with
/// `.delegate(.open(Route))`; only this reducer changes navigation.
@Reducer
public struct AppFeature {
  @ObservableState
  public struct State: Equatable {
    public var selectedTab: AppTab = .shelf
    public var tabs: TabBarLayout = .default
    public var shelf = ShelfFeature.State()
    public var shelfPath = StackState<AppPath.State>()
    public var find = FindFeature.State()
    public var findPath = StackState<AppPath.State>()
    /// Scan presents instead of selecting a tab (PD-117): Add by hand in M3, the camera from M6.
    @Presents public var addByHand: AddByHandFeature.State?

    public init() {}
  }

  public enum Action: ViewAction {
    case addByHand(PresentationAction<AddByHandFeature.Action>)
    case find(FindFeature.Action)
    case findPath(StackActionOf<AppPath>)
    case shelf(ShelfFeature.Action)
    case shelfPath(StackActionOf<AppPath>)
    case view(View)

    @CasePathable
    public enum View: Equatable, Sendable {
      case tabTapped(AppTab)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Scope(state: \.shelf, action: \.shelf) { ShelfFeature() }
    Scope(state: \.find, action: \.find) { FindFeature() }
    Reduce { state, action in
      switch action {
      case .shelf(.delegate(.open(let route))):
        Self.push(route, onto: &state.shelfPath)
        return .none
      case .shelf(.delegate(.addByHand)):
        state.addByHand = AddByHandFeature.State()
        return .none
      case .addByHand:
        return .none
      case .find(.delegate(.open(let route))):
        Self.push(route, onto: &state.findPath)
        return .none
      case .find:
        return .none
      case .findPath(.element(_, .collection(.delegate(.open(let route))))),
        .findPath(.element(_, .places(.delegate(.open(let route))))),
        .findPath(.element(_, .place(.delegate(.open(let route))))):
        Self.push(route, onto: &state.findPath)
        return .none
      case .findPath:
        return .none
      case .shelf:
        return .none
      case .shelfPath(.element(_, .collection(.delegate(.open(let route))))),
        .shelfPath(.element(_, .places(.delegate(.open(let route))))),
        .shelfPath(.element(_, .place(.delegate(.open(let route))))):
        Self.push(route, onto: &state.shelfPath)
        return .none
      case .shelfPath:
        return .none
      case .view(.tabTapped(let tab)):
        if tab.presents {
          state.addByHand = AddByHandFeature.State()
        } else if tab == state.selectedTab, tab == .shelf {
          // Tapping the tab you're on goes back to its root.
          state.shelfPath.removeAll()
        } else if tab == state.selectedTab, tab == .find {
          state.findPath.removeAll()
        } else {
          state.selectedTab = tab
        }
        return .none
      }
    }
    .forEach(\.shelfPath, action: \.shelfPath)
    .forEach(\.findPath, action: \.findPath)
    .ifLet(\.$addByHand, action: \.addByHand) { AddByHandFeature() }
  }

  /// The one place a route becomes a screen. Routes whose screen arrives later in M3 do nothing yet.
  static func push(_ route: Route, onto path: inout StackState<AppPath.State>) {
    switch route {
    case .collection(let id):
      path.append(.collection(CollectionFeature.State(id: id)))
    case .object(let id):
      path.append(.object(ObjectFeature.State(id: id)))
    case .places:
      path.append(.places(PlacesFeature.State()))
    case .place(let id):
      path.append(.place(PlaceFeature.State(id: id)))
    case .wishlist:
      break
    }
  }
}

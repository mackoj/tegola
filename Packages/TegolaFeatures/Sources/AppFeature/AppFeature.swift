public import CollectionFeature
public import ComposableArchitecture
public import ObjectFeature
public import ShelfFeature
public import TegolaModel

/// Every screen a tab's stack can push (PLAN §5). One enum for every tab, defined here: only the root pushes.
@Reducer
public enum AppPath {
  case collection(CollectionFeature)
  case object(ObjectFeature)
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
    /// Scan presents the add sheet instead of selecting a tab (PD-117). It becomes the camera with M6.
    public var isCapturePresented = false

    public init() {}
  }

  public enum Action: ViewAction {
    case shelf(ShelfFeature.Action)
    case shelfPath(StackActionOf<AppPath>)
    case view(View)

    @CasePathable
    public enum View: Equatable, Sendable {
      case captureDismissed
      case tabTapped(AppTab)
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Scope(state: \.shelf, action: \.shelf) { ShelfFeature() }
    Reduce { state, action in
      switch action {
      case .shelf(.delegate(.open(let route))):
        Self.push(route, onto: &state.shelfPath)
        return .none
      case .shelf(.delegate(.addByHand)):
        state.isCapturePresented = true
        return .none
      case .shelf:
        return .none
      case .shelfPath(.element(_, .collection(.delegate(.open(let route))))):
        Self.push(route, onto: &state.shelfPath)
        return .none
      case .shelfPath:
        return .none
      case .view(.captureDismissed):
        state.isCapturePresented = false
        return .none
      case .view(.tabTapped(let tab)):
        if tab.presents {
          state.isCapturePresented = true
        } else if tab == state.selectedTab, tab == .shelf {
          // Tapping the tab you're on goes back to its root.
          state.shelfPath.removeAll()
        } else {
          state.selectedTab = tab
        }
        return .none
      }
    }
    .forEach(\.shelfPath, action: \.shelfPath)
  }

  /// The one place a route becomes a screen. Routes whose screen arrives later in M3 do nothing yet.
  static func push(_ route: Route, onto path: inout StackState<AppPath.State>) {
    switch route {
    case .collection(let id):
      path.append(.collection(CollectionFeature.State(id: id)))
    case .object(let id):
      path.append(.object(ObjectFeature.State(id: id)))
    case .places, .place, .wishlist:
      break
    }
  }
}

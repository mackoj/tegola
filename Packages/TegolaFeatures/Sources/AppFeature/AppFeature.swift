public import ComposableArchitecture
public import TegolaModel

/// The root: the tab bar and, from M3 on, one navigation stack per tab owned here (PLAN §5). Children ask for
/// screens with `.delegate(.open(Route))`; only this reducer changes navigation.
@Reducer
public struct AppFeature {
  @ObservableState
  public struct State: Equatable {
    public var selectedTab: Tab = .shelf
    public var tabs: TabBarLayout = .default
    /// Scan presents the camera instead of selecting a tab (PD-117). It becomes `@Presents var capture` with M6.
    public var isCapturePresented = false

    public init() {}
  }

  public enum Action: ViewAction {
    case view(View)

    @CasePathable
    public enum View: Equatable, Sendable {
      case tabTapped(Tab)
      case captureDismissed
    }
  }

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(.tabTapped(tab)):
        if tab.presents {
          state.isCapturePresented = true
        } else {
          state.selectedTab = tab
        }
        return .none
      case .view(.captureDismissed):
        state.isCapturePresented = false
        return .none
      }
    }
  }
}

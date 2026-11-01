public import AddByHandFeature
public import CaptureFeature
public import CollectionFeature
public import ComposableArchitecture
public import FindFeature
public import FirstPieceFeature
public import Foundation
public import ImportFeature
public import ObjectFeature
public import PersonFeature
public import PlacesFeature
public import ReviewFeature
import SQLiteData
public import ShelfFeature
public import SignalsFeature
import TegolaClients
public import TegolaModel
import TegolaStorage

/// Every screen a tab's stack can push (PLAN §5). One enum for every tab, defined here: only the root pushes.
@Reducer
public enum AppPath {
  case collection(CollectionFeature)
  case object(ObjectFeature)
  case person(PersonFeature)
  case place(PlaceFeature)
  case places(PlacesFeature)
  case review(ReviewFeature)
  case signals(SignalsFeature)
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
    /// Add by hand: the empty shelf's Type it, and the camera's.
    @Presents public var addByHand: AddByHandFeature.State?
    /// Scan presents instead of selecting a tab (PD-117): the camera (F6, T6.9).
    @Presents public var capture: CaptureFeature.State?
    /// Bringing a list (F9): from the empty shelf or Add.
    @Presents public var importing: ImportFeature.State?
    /// The next sheet, once the one on screen has gone: SwiftUI presents one at a time.
    public var nextSheet: Sheet?

    public enum Sheet: Hashable, Sendable {
      case addByHand
      case capture
      case importing
    }
    /// The first piece (PLAN F2): the app opens on it while the shelf is empty and it hasn't been skipped.
    @Presents public var firstPiece: FirstPieceFeature.State?

    public init() {}
  }

  public enum Action: ViewAction {
    case addByHand(PresentationAction<AddByHandFeature.Action>)
    case capture(PresentationAction<CaptureFeature.Action>)
    case importing(PresentationAction<ImportFeature.Action>)
    case find(FindFeature.Action)
    case findPath(StackActionOf<AppPath>)
    case firstPiece(PresentationAction<FirstPieceFeature.Action>)
    /// Scan, once the first piece's cover has gone: SwiftUI can't present a sheet while a cover is dismissing.
    case presentScan
    case shelf(ShelfFeature.Action)
    case shelfPath(StackActionOf<AppPath>)
    case view(View)

    @CasePathable
    public enum View: Equatable, Sendable {
      /// Debug builds' `--import-fixture`: Bring your list with a file already chosen (journey 2's UI test).
      case importFixture(name: String, data: Data)
      case onAppear
      case tabTapped(AppTab)
    }
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.reachability) var reachability

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
      case .shelf(.delegate(.scanFirstObject)):
        state.firstPiece = FirstPieceFeature.State()
        return .none
      case .firstPiece(.presented(.delegate(.skipped))), .firstPiece(.presented(.delegate(.finished))),
        .firstPiece(.presented(.delegate(.closed))):
        state.firstPiece = nil
        return .none
      case .firstPiece(.presented(.delegate(.oneAtATime))):
        // The next piece goes through Scan, like every piece after the first.
        state.firstPiece = nil
        return .run { [clock] send in
          try await clock.sleep(for: .milliseconds(600))
          await send(.presentScan)
        }
      case .presentScan:
        switch state.nextSheet ?? .capture {
        case .addByHand: state.addByHand = AddByHandFeature.State()
        case .capture: state.capture = CaptureFeature.State()
        case .importing: state.importing = ImportFeature.State()
        }
        state.nextSheet = nil
        return .none
      case .capture(.presented(.delegate(.queued))):
        return lookups()
      case .capture(.presented(.delegate(.typeIt))):
        state.capture = nil
        state.nextSheet = .addByHand
        return .run { [clock] send in
          try await clock.sleep(for: .milliseconds(600))
          await send(.presentScan)
        }
      case .capture(.presented(.delegate(.review))):
        state.capture = nil
        state.selectedTab = .shelf
        Self.push(.review, onto: &state.shelfPath)
        return .none
      case .capture:
        return .none
      case .shelf(.delegate(.bringList)):
        state.importing = ImportFeature.State()
        return .none
      case .addByHand(.presented(.delegate(.importList))):
        state.addByHand = nil
        state.nextSheet = .importing
        return .run { [clock] send in
          try await clock.sleep(for: .milliseconds(600))
          await send(.presentScan)
        }
      case .importing(.presented(.delegate(.match(let rows, let objects)))):
        // Matching outlives the sheet (D-74): the answers wait for Review; the sheet shows the count if it's open.
        return .run { send in
          let matched = try await ImportFeature.match(rows, objects: objects)
          await send(.importing(.presented(.matchedRows(matched))))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .importing(.presented(.delegate(.finished(let collection)))):
        state.selectedTab = .shelf
        if let collection { Self.push(.collection(collection), onto: &state.shelfPath) }
        return .none
      case .importing:
        return .none
      case .firstPiece:
        return .none
      case .view(.importFixture(let name, let data)):
        state.firstPiece = nil
        state.importing = ImportFeature.State()
        return .send(.importing(.presented(.view(.fileChosen(name: name, data: data)))))
      case .view(.onAppear):
        return .merge(openOnFirstPiece(&state), lookups())
      case .addByHand:
        return .none
      case .find(.delegate(.open(let route))):
        Self.push(route, onto: &state.findPath)
        return .none
      case .find:
        return .none
      case .findPath(.element(_, .collection(.delegate(.open(let route))))),
        .findPath(.element(_, .places(.delegate(.open(let route))))),
        .findPath(.element(_, .place(.delegate(.open(let route))))),
        .findPath(.element(_, .signals(.delegate(.open(let route))))),
        .findPath(.element(_, .review(.delegate(.open(let route))))),
        .findPath(.element(_, .person(.delegate(.open(let route))))):
        Self.push(route, onto: &state.findPath)
        return .none
      case .findPath:
        return .none
      case .shelf:
        return .none
      case .shelfPath(.element(_, .collection(.delegate(.open(let route))))),
        .shelfPath(.element(_, .places(.delegate(.open(let route))))),
        .shelfPath(.element(_, .place(.delegate(.open(let route))))),
        .shelfPath(.element(_, .signals(.delegate(.open(let route))))),
        .shelfPath(.element(_, .review(.delegate(.open(let route))))),
        .shelfPath(.element(_, .person(.delegate(.open(let route))))):
        Self.push(route, onto: &state.shelfPath)
        return .none
      case .shelfPath:
        return .none
      case .view(.tabTapped(let tab)):
        if tab.presents {
          state.capture = CaptureFeature.State()
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
    .ifLet(\.$capture, action: \.capture) { CaptureFeature() }
    .ifLet(\.$importing, action: \.importing) { ImportFeature() }
    .ifLet(\.$firstPiece, action: \.firstPiece) { FirstPieceFeature() }
  }

  /// The app opens on the first piece while the shelf is empty and it hasn't been skipped (PLAN F2).
  func openOnFirstPiece(_ state: inout State) -> Effect<Action> {
    @Dependency(\.defaultDatabase) var database
    do {
      let snapshot = try database.read { db in try ShelfRequest().fetch(db) }
      if snapshot.opensOnFirstPiece, state.firstPiece == nil { state.firstPiece = FirstPieceFeature.State() }
    } catch {
      reportIssue(error)
    }
    return .none
  }

  /// The lookup worker (PLAN §7, D-73): whenever the network is there, it drains the queue, then waits for the next
  /// request to be ready. Restarted when something is queued, so a capture's lookup goes out at once.
  func lookups() -> Effect<Action> {
    .run { [reachability] _ in
      for await online in reachability.updates() where online {
        try await LookupWorker.run()
      }
    } catch: { error, _ in
      if !(error is CancellationError) { reportIssue(error) }
    }
    .cancellable(id: CancelID.lookups, cancelInFlight: true)
  }

  enum CancelID { case lookups }

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
    case .signals:
      path.append(.signals(SignalsFeature.State()))
    case .review:
      path.append(.review(ReviewFeature.State()))
    case .person(let id):
      path.append(.person(PersonFeature.State(id: id)))
    case .wishlist:
      break
    }
  }
}

#if canImport(SwiftUI)
  import AddByHandFeature
  import CaptureFeature
  import CollectionFeature
  import FindFeature
  import FirstPieceFeature
  import ObjectFeature
  import PlacesFeature
  import SignalsFeature
  public import ComposableArchitecture
  import ShelfFeature
  public import SwiftUI
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  /// The root view: each tab's stack above the tab bar (board 29, state 5). Find, Activity and You get their screens
  /// later in M3 and in M7–M8; until then they show their title.
  @ViewAction(for: AppFeature.self)
  public struct AppView: View {
    @Bindable public var store: StoreOf<AppFeature>
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<AppFeature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        Group {
          switch store.selectedTab {
          case .shelf: shelfStack
          case .find: findStack
          default: placeholder(store.selectedTab)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        tabBar
      }
      .background(theme[.surface].color)
      .ignoresSafeArea(.container, edges: .bottom)
      .sheet(item: $store.scope(state: \.addByHand, action: \.addByHand)) { add in
        AddByHandView(store: add)
      }
      .sheet(item: $store.scope(state: \.capture, action: \.capture)) { capture in
        CaptureView(store: capture)
      }
      #if os(iOS)
        .fullScreenCover(item: $store.scope(state: \.firstPiece, action: \.firstPiece)) { first in
          FirstPieceView(store: first)
        }
      #else
        .sheet(item: $store.scope(state: \.firstPiece, action: \.firstPiece)) { first in
          FirstPieceView(store: first)
        }
      #endif
      .onAppear { send(.onAppear) }
    }

    var shelfStack: some View {
      NavigationStack(path: $store.scope(state: \.shelfPath, action: \.shelfPath)) {
        ShelfView(store: store.scope(state: \.shelf, action: \.shelf))
          #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
          #endif
      } destination: { path in
        switch path.case {
        case .collection(let store):
          CollectionView(store: store)
        case .object(let store):
          ObjectView(store: store)
        case .place(let store):
          PlaceView(store: store)
        case .places(let store):
          PlacesView(store: store)
        case .signals(let store):
          SignalsView(store: store)
        }
      }
    }

    var findStack: some View {
      NavigationStack(path: $store.scope(state: \.findPath, action: \.findPath)) {
        FindView(store: store.scope(state: \.find, action: \.find))
          #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
          #endif
      } destination: { path in
        switch path.case {
        case .collection(let store): CollectionView(store: store)
        case .object(let store): ObjectView(store: store)
        case .place(let store): PlaceView(store: store)
        case .places(let store): PlacesView(store: store)
        case .signals(let store): SignalsView(store: store)
        }
      }
    }

    func placeholder(_ tab: AppTab) -> some View {
      Text(tab.title)
        .tegolaTextStyle(TegolaType.displayTitle)
        .foregroundStyle(.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.top, TegolaSpace.l)
    }

    var tabBar: some View {
      let order = store.tabs.order.filter { !$0.presents }
      let items = order.map { TabBarItem(id: $0.rawValue, label: Text($0.title)) }
      return TegolaTabBar(
        leading: Array(items.prefix(2)),
        trailing: Array(items.dropFirst(2)),
        selected: store.selectedTab.rawValue,
        scanLabel: Text(AppTab.scan.title),
        select: { id in if let tab = AppTab(rawValue: id) { send(.tabTapped(tab)) } },
        scan: { send(.tabTapped(.scan)) }
      )
    }
  }

  extension AppTab {
    var title: String {
      switch self {
      case .shelf: String(localized: "Shelf", bundle: .module)
      case .find: String(localized: "Find", bundle: .module)
      case .scan: String(localized: "Scan", bundle: .module)
      case .activity: String(localized: "Activity", bundle: .module)
      case .you: String(localized: "You", bundle: .module)
      }
    }
  }

  #Preview("Seeded") {
    let _ = prepareDependencies { try! $0.bootstrapDatabase(seed: true) }
    AppView(store: Store(initialState: AppFeature.State()) { AppFeature() })
  }
#endif

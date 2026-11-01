#if canImport(SwiftUI)
  import AddByHandFeature
  import CaptureFeature
  import CollectionFeature
  import FindFeature
  import ImportFeature
  import FirstPieceFeature
  import ObjectFeature
  import PlacesFeature
  import ReviewFeature
  import SignalsFeature
  public import ComposableArchitecture
  import ShelfFeature
  public import SwiftUI
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  /// The root view: the system tab bar, one stack per tab (D-77). Activity and You get their screens in M7 and M8;
  /// until then they show their title. Scan presents the camera rather than selecting (PD-117).
  @ViewAction(for: AppFeature.self)
  public struct AppView: View {
    @Bindable public var store: StoreOf<AppFeature>
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<AppFeature>) {
      self.store = store
    }

    public var body: some View {
      // Choosing Scan sends `tabTapped(.scan)`, which presents the camera and leaves the selection where it was.
      TabView(selection: $store.selectedTab.sending(\.view.tabTapped)) {
        ForEach(store.tabs.order, id: \.self) { tab in
          Tab(value: tab) {
            screen(tab)
          } label: {
            tab.action.item
          }
          .accessibilityIdentifier("tab.\(tab.rawValue)")
        }
      }
      .tint(theme[.accentAction].color)
      .sheet(item: $store.scope(state: \.addByHand, action: \.addByHand)) { add in
        AddByHandView(store: add)
      }
      .sheet(item: $store.scope(state: \.capture, action: \.capture)) { capture in
        CaptureView(store: capture)
      }
      .sheet(item: $store.scope(state: \.importing, action: \.importing)) { importing in
        ImportView(store: importing)
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

    @ViewBuilder
    func screen(_ tab: AppTab) -> some View {
      switch tab {
      case .shelf: shelfStack
      case .find: findStack
      // Scan never shows a screen of its own: choosing it presents the camera.
      case .scan: Color.clear
      case .activity, .you: placeholder(tab)
      }
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
        case .review(let store):
          ReviewView(store: store)
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
        case .review(let store): ReviewView(store: store)
        }
      }
    }

    func placeholder(_ tab: AppTab) -> some View {
      tab.action.label
        .tegolaTextStyle(TegolaType.displayTitle)
        .foregroundStyle(.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.top, TegolaSpace.l)
    }
  }

  extension AppTab {
    /// The shared action a tab is: its words and symbol (D-77).
    var action: TegolaAction {
      switch self {
      case .shelf: .shelf
      case .find: .find
      case .scan: .scan
      case .activity: .activity
      case .you: .you
      }
    }
  }

  #Preview("Seeded") {
    let _ = prepareDependencies { try! $0.bootstrapDatabase(seed: true) }
    AppView(store: Store(initialState: AppFeature.State()) { AppFeature() })
  }
#endif

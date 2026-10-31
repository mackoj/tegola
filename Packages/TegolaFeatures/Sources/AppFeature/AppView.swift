#if canImport(SwiftUI)
  public import ComposableArchitecture
  public import SwiftUI
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel

  /// The app shell for M1: the five tabs and an empty screen behind each. The real tab bar (the raised scan button,
  /// board `chrome`) is a design-system component in M3; the screens arrive with their features.
  @ViewAction(for: AppFeature.self)
  public struct AppView: View {
    public let store: StoreOf<AppFeature>
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<AppFeature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        Text(store.selectedTab.title)
          .tegolaTextStyle(TegolaType.displayTitle)
          .foregroundStyle(.text)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(.horizontal, TegolaSpace.gutter)
          .padding(.top, TegolaSpace.l)
        HStack {
          ForEach(store.tabs.order, id: \.self) { tab in
            Button(tab.title) { send(.tabTapped(tab)) }
              .tegolaTextStyle(TegolaType.metaSmall)
              .foregroundStyle(tab == store.selectedTab ? .text : .textMeta)
              .frame(maxWidth: .infinity, minHeight: TegolaMetrics.minimumHitTarget)
              .accessibilityIdentifier("tab.\(tab.rawValue)")
          }
        }
        .padding(.horizontal, TegolaSpace.s)
      }
      .background(theme[.surface].color)
      .sheet(isPresented: Binding(get: { store.isCapturePresented }, set: { if !$0 { send(.captureDismissed) } })) {
        Text(String(localized: "Scan", bundle: .module))
          .tegolaTextStyle(TegolaType.displayTitle)
          .foregroundStyle(.textOnStage)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(theme[.surfaceCamera].color)
      }
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

  #Preview("Shelf selected") {
    AppView(store: Store(initialState: AppFeature.State()) { AppFeature() })
  }

  #Preview("Scan presented") {
    var state = AppFeature.State()
    state.isCapturePresented = true
    return AppView(store: Store(initialState: state) { AppFeature() })
  }
#endif

import AppFeature
import ComposableArchitecture
import SwiftUI
import TegolaDesignSystem
import TegolaDesignTokens

@main
struct TegolaApp: App {
  @MainActor static let store = Store(initialState: AppFeature.State()) { AppFeature() }

  init() {
    TegolaFonts.register()
    #if DEBUG
      LaunchArguments(ProcessInfo.processInfo.arguments).apply()
    #else
      AppBootstrap.prepare()
    #endif
  }

  var body: some Scene {
    WindowGroup {
      AppView(store: Self.store)
        .tegolaTheme(.board)
        #if DEBUG
          .task {
            let arguments = LaunchArguments(ProcessInfo.processInfo.arguments)
            if let path = arguments.importFixture, let data = FileManager.default.contents(atPath: path) {
              Self.store.send(.view(.importFixture(name: (path as NSString).lastPathComponent, data: data)))
            }
          }
        #endif
    }
  }
}

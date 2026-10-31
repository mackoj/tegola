public import Dependencies
import DependenciesMacros
import Foundation
import SQLiteData
public import TegolaStorage

/// Writes the collector's settings (PD-161). Not a shelf change, so not a command: settings have no history. Screens
/// read them through the shelf's query (`ShelfSnapshot`).
@DependencyClient
public struct SettingsClient: Sendable {
  public var set: @Sendable (_ key: SettingKey, _ value: String) throws -> Void
}

extension SettingsClient: DependencyKey {
  public static var liveValue: SettingsClient {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.catalogue) var catalogue
    let store = ShelfStore(migrated: database, catalogue: catalogue)
    return SettingsClient { key, value in try store.set(key, to: value) }
  }

  public static let testValue = SettingsClient()
}

extension DependencyValues {
  public var settings: SettingsClient {
    get { self[SettingsClient.self] }
    set { self[SettingsClient.self] = newValue }
  }
}

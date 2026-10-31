import ComposableArchitecture
import TegolaStorage

/// What the app does before its first screen: open the database, and in debug builds honour the UI tests' launch
/// arguments (PLAN §2.6). The app target calls this from its `init`, so it imports `AppFeature` alone.
public enum AppBootstrap {
  /// `reset` starts from an empty shelf; `seed` plants the seed shelf on an empty one. Both are ignored in Release.
  public static func prepare(reset: Bool = false, seed: Bool = false) {
    prepareDependencies { values in
      do {
        try values.bootstrapDatabase(reset: reset, seed: seed)
      } catch {
        reportIssue(error)
      }
    }
  }
}

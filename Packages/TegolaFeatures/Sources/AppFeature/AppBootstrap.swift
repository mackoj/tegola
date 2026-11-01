import ComposableArchitecture
import Foundation
import TegolaStorage

/// What the app does before its first screen: open the database, and in debug builds honour the UI tests' launch
/// arguments (PLAN §2.6). The app target calls this from its `init`, so it imports `AppFeature` alone.
public enum AppBootstrap {
  /// `reset` starts from an empty shelf; `seed` plants the seed shelf on an empty one. `daysAhead` moves the app's
  /// clock forward, so a UI test can see a loan come due (journey 3). All three are for debug builds only.
  public static func prepare(reset: Bool = false, seed: Bool = false, daysAhead: Int = 0) {
    prepareDependencies { values in
      if daysAhead != 0 {
        let offset = TimeInterval(daysAhead) * 86_400
        let live = values.date
        values.date = DateGenerator { live.now.addingTimeInterval(offset) }
      }
      do {
        try values.bootstrapDatabase(reset: reset, seed: seed)
      } catch {
        reportIssue(error)
      }
    }
  }
}

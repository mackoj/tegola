public import Dependencies
public import Foundation
import SQLiteData
import TegolaCatalogue
import TegolaClients
import TegolaModel
import TegolaStorage

/// The time every feature test runs at.
public let testNow = Date(timeIntervalSince1970: 1_800_000_000)

extension DependencyValues {
  /// The seed shelf in an in-memory database, the clock stopped at `testNow` and ids counting up, with `ShelfClient`
  /// over that database (PLAN §2.6: every dependency overridden, the seed shelf in an in-memory database).
  public mutating func seededShelf(seed: Bool = true) throws {
    date.now = testNow
    uuid = .incrementing
    try bootstrapDatabase(seed: seed)
    let store = ShelfStore(migrated: defaultDatabase, catalogue: catalogue)
    shelf = .store(store)
    settings = SettingsClient { key, value in try store.set(key, to: value) }
    photoStore = .inMemory()
  }
}

public import Dependencies
import Foundation
public import SQLiteData
public import TegolaCatalogue
import TegolaModel

/// `uuid()` in SQL, from the `uuid` dependency, so a row SQLite gives an id to is deterministic in tests (D-24).
@DatabaseFunction nonisolated func uuid() -> UUID {
  @Dependency(\.uuid) var uuid
  return uuid()
}

extension DependencyValues {
  /// Opens the app's database and runs the migrations. `reset` starts from an empty shelf and `seed` plants the seed
  /// shelf on an empty one: both are the UI tests' launch arguments, and debug builds only (PLAN §2.6).
  public mutating func bootstrapDatabase(reset: Bool = false, seed: Bool = false) throws {
    let database = try SQLiteData.defaultDatabase(configuration: ShelfStore.configuration())
    #if DEBUG
      if reset { try database.erase() }
    #endif
    try ShelfStore.migrator.migrate(database)
    defaultDatabase = database
    #if DEBUG
      if seed {
        let store = ShelfStore(migrated: database, catalogue: try Catalogue.bundled())
        if try store.shelf().objects.isEmpty {
          let uuid = self.uuid
          try Seed.plant(in: store, at: date.now, makeID: { uuid() })
        }
      }
    #endif
  }
}

extension ShelfStore {
  /// A store over a database `bootstrapDatabase` has already migrated.
  public init(migrated database: any DatabaseWriter, catalogue: Catalogue) {
    self.database = database
    self.catalogue = catalogue
  }
}

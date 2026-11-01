public import Dependencies
public import Foundation
import SQLiteData
import TegolaCatalogue
import TegolaClients
public import TegolaModel
import TegolaStorage

extension Calendar {
  /// Every feature test's calendar: Gregorian in UTC, so a clock's year is the same on any machine.
  public static let testUTC: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()
}

/// The time every feature test runs at.
public let testNow = Date(timeIntervalSince1970: 1_800_000_000)

extension DependencyValues {
  /// The seed shelf in an in-memory database, the clock stopped at `testNow` and ids counting up, with `ShelfClient`
  /// over that database (PLAN §2.6: every dependency overridden, the seed shelf in an in-memory database).
  public mutating func seededShelf(seed: Bool = true) throws {
    date.now = testNow
    calendar = .testUTC
    uuid = .incrementing
    try bootstrapDatabase(seed: seed)
    let store = ShelfStore(migrated: defaultDatabase, catalogue: catalogue)
    shelf = .store(store)
    settings = SettingsClient { key, value in try store.set(key, to: value) }
    photoStore = .inMemory()
  }
}

/// Adds a Game Boy cartridge from 1994 to the seed's games: its save battery is due at `testNow` (F15, journey 5).
public func dueCartridge(_ title: String = "Link's Awakening") throws -> ObjectID {
  @Dependency(\.shelf) var shelf
  @Dependency(\.defaultDatabase) var database
  let draft = ObjectDraft(
    type: "video-game",
    subtype: "game-boy",
    values: [.title: .text(title), .year: .year(1994), .field("region"): .text("PAL")]
  )
  let games = try database.read { db in
    try ShelfRequest().fetch(db).shelf.collections.values.first { $0.typeID == "video-game" }?.id
  }
  let choice = games.map(CollectionChoice.existing) ?? .new(name: "The Library")
  return try shelf.perform(.add(draft, to: choice, origin: .typed)).createdObjects[0]
}

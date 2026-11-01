public import Foundation
public import SQLiteData
import TegolaModel

// The rows, as SQLite holds them (PLAN §3.2). Each row keeps its model value as JSON in `data`, which is what's read
// back, exactly: Foundation's coders keep a date's every digit, where SQLite's text dates and StructuredQueries' JSON
// coders keep milliseconds. The other columns are copies of parts of it for queries, indexes and screens, written
// from the same value in the same statement (D-39).

/// The event log: append-only, the source of truth.
@Table("events")
struct EventRow: Identifiable {
  let id: UUID
  var seq: Int
  var objectID: UUID?
  var batchID: UUID?
  /// `ShelfEvent.Kind.name`: what the History slot filters on.
  var kind: String
  var at: Date
  var source: String
  /// The whole event as JSON (`StoredJSON`), read back exactly (D-39): `at` in its own column keeps milliseconds.
  var data: String
}

@Table("collections")
struct CollectionRow: Identifiable {
  let id: UUID
  var name: String
  var typeID: String?
  var sortKey: Int
  var createdAt: Date
  var deletedAt: Date?
  /// The model value as JSON (`StoredJSON`).
  var data: String
}

@Table("objects")
struct ObjectRow: Identifiable {
  let id: UUID
  var collectionID: UUID
  var typeID: String
  var subtype: String?
  var workID: UUID?
  var title: String
  var placeID: UUID?
  var quantity: Int
  var ownership: String
  var identity: String
  var isGrail: Bool
  var isLetGo: Bool
  var createdAt: Date
  var updatedAt: Date
  var deletedAt: Date?
  /// The model value as JSON (`StoredJSON`).
  var data: String
}

@Table("works")
struct WorkRow: Identifiable {
  let id: UUID
  var title: String
  var typeID: String
  var deletedAt: Date?
  /// The model value as JSON (`StoredJSON`).
  var data: String
}

@Table("places")
struct PlaceRow: Identifiable {
  let id: UUID
  var name: String
  var parentID: UUID?
  var createdAt: Date
  var deletedAt: Date?
  /// The model value as JSON (`StoredJSON`).
  var data: String
}

@Table("persons")
struct PersonRow: Identifiable {
  let id: UUID
  var name: String
  var lastUsedAt: Date
  var deletedAt: Date?
  /// The model value as JSON (`StoredJSON`).
  var data: String
}

@Table("loans")
struct LoanRow: Identifiable {
  let id: UUID
  var objectID: UUID
  var personID: UUID
  var direction: String
  var dueAt: Date?
  var openedAt: Date
  var closedAt: Date?
  var deletedAt: Date?
  /// The model value as JSON (`StoredJSON`).
  var data: String
}

@Table("photos")
struct PhotoRow: Identifiable {
  let id: UUID
  var objectID: UUID
  var position: Int
  var fileName: String
  var takenAt: Date
  var deletedAt: Date?
  /// The model value as JSON (`StoredJSON`).
  var data: String
}

/// A setting the collector changed (PD-161, ADR-0008): only those are stored, so a missing row is the default. Not a
/// shelf change, so not an event. Each setting has a fixed id, because `SyncEngine` allows no unique constraint on
/// `key` (D-44).
@Table("settings")
public struct SettingRow: Identifiable, Sendable {
  public let id: UUID
  public var key: String
  public var value: String
}

/// The settings the app knows, each with its fixed row id.
public enum SettingKey: String, CaseIterable, Sendable {
  /// `MoneyVisibility`: off by default (PD-138).
  case money
  /// The collection the last object was added to: where Add to points next (F6).
  case lastCollection
  /// The clock notification offer's answer, once given: `accepted` or `declined` (F15: offered once).
  case notificationsOffer
  /// Opt-in clocks the collector turned on, comma-separated (`unfinished`, D-20, D-57).
  case optedInClocks

  public var id: UUID {
    switch self {
    case .money: UUID(uuidString: "5E771965-0000-4000-8000-000000000001")!
    case .lastCollection: UUID(uuidString: "5E771965-0000-4000-8000-000000000002")!
    case .notificationsOffer: UUID(uuidString: "5E771965-0000-4000-8000-000000000003")!
    case .optedInClocks: UUID(uuidString: "5E771965-0000-4000-8000-000000000004")!
    }
  }
}

extension ShelfStore {
  /// The migrations, under `SyncEngine`'s rules from the first one, so iCloud sync can be switched on later without a
  /// migration (Q4, ADR-0006): a `TEXT` UUID key, `NOT NULL ON CONFLICT REPLACE DEFAULT (uuid())`, soft deletes, and
  /// no unique constraint beyond the key (two devices can create the same place offline; D-24).
  public static var migrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("Create the event log and its projection") { db in
      try #sql(
        """
        CREATE TABLE "events" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "seq" INTEGER NOT NULL,
          "objectID" TEXT,
          "batchID" TEXT,
          "kind" TEXT NOT NULL,
          "at" TEXT NOT NULL,
          "source" TEXT NOT NULL,
          "data" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      // History only appends (PD-051): SQLite itself refuses to change or remove an event.
      try #sql(
        """
        CREATE TRIGGER "events_are_append_only_update" BEFORE UPDATE ON "events"
        BEGIN SELECT RAISE(ABORT, 'events are append-only'); END
        """
      )
      .execute(db)
      try #sql(
        """
        CREATE TRIGGER "events_are_append_only_delete" BEFORE DELETE ON "events"
        BEGIN SELECT RAISE(ABORT, 'events are append-only'); END
        """
      )
      .execute(db)
      try #sql(#"CREATE INDEX "index_events_on_objectID" ON "events"("objectID")"#).execute(db)
      try #sql(#"CREATE INDEX "index_events_on_batchID" ON "events"("batchID")"#).execute(db)
      try #sql(#"CREATE INDEX "index_events_on_seq" ON "events"("seq")"#).execute(db)
      try #sql(
        """
        CREATE TABLE "collections" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "name" TEXT NOT NULL,
          "typeID" TEXT,
          "sortKey" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
          "createdAt" TEXT NOT NULL,
          "deletedAt" TEXT,
          "data" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql(
        """
        CREATE TABLE "objects" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "collectionID" TEXT NOT NULL REFERENCES "collections"("id") ON DELETE CASCADE,
          "typeID" TEXT NOT NULL,
          "subtype" TEXT,
          "workID" TEXT,
          "title" TEXT NOT NULL,
          "placeID" TEXT,
          "quantity" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 1,
          "ownership" TEXT NOT NULL,
          "identity" TEXT NOT NULL,
          "isGrail" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
          "isLetGo" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
          "createdAt" TEXT NOT NULL,
          "updatedAt" TEXT NOT NULL,
          "deletedAt" TEXT,
          "data" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql(#"CREATE INDEX "index_objects_on_collectionID" ON "objects"("collectionID")"#).execute(db)
      try #sql(#"CREATE INDEX "index_objects_on_placeID" ON "objects"("placeID")"#).execute(db)
      try #sql(
        """
        CREATE TABLE "works" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "title" TEXT NOT NULL,
          "typeID" TEXT NOT NULL,
          "deletedAt" TEXT,
          "data" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql(
        """
        CREATE TABLE "places" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "name" TEXT NOT NULL,
          "parentID" TEXT,
          "createdAt" TEXT NOT NULL,
          "deletedAt" TEXT,
          "data" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql(
        """
        CREATE TABLE "persons" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "name" TEXT NOT NULL,
          "lastUsedAt" TEXT NOT NULL,
          "deletedAt" TEXT,
          "data" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql(
        """
        CREATE TABLE "loans" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "objectID" TEXT NOT NULL REFERENCES "objects"("id") ON DELETE CASCADE,
          "personID" TEXT NOT NULL REFERENCES "persons"("id") ON DELETE CASCADE,
          "direction" TEXT NOT NULL,
          "dueAt" TEXT,
          "openedAt" TEXT NOT NULL,
          "closedAt" TEXT,
          "deletedAt" TEXT,
          "data" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql(#"CREATE INDEX "index_loans_on_objectID" ON "loans"("objectID")"#).execute(db)
    }
    migrator.registerMigration("Create settings") { db in
      try #sql(
        """
        CREATE TABLE "settings" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "key" TEXT NOT NULL,
          "value" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
    }
    migrator.registerMigration("Create photos") { db in
      try #sql(
        """
        CREATE TABLE "photos" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "objectID" TEXT NOT NULL REFERENCES "objects"("id") ON DELETE CASCADE,
          "position" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,
          "fileName" TEXT NOT NULL,
          "takenAt" TEXT NOT NULL,
          "deletedAt" TEXT,
          "data" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql(#"CREATE INDEX "index_photos_on_objectID" ON "photos"("objectID")"#).execute(db)
    }
    return migrator
  }
}

/// The JSON the `data` columns hold: Foundation's coders, keys sorted so the same value is the same text.
enum StoredJSON {
  static func encode(_ value: some Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    // Encoding a model value can't fail: every one is plain Codable data.
    return String(decoding: (try? encoder.encode(value)) ?? Data("null".utf8), as: UTF8.self)
  }

  static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(text.utf8))
  }
}

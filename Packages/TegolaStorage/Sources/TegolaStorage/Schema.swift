public import Foundation
public import SQLiteData
import TegolaModel

// The rows, as SQLite holds them (PLAN §3.2). Each projection row keeps its model value as JSON in `data`, which is
// what's read back, exactly. The other columns are copies of parts of it for queries, indexes and screens, written
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
  @Column(as: ShelfEvent.Kind.JSONRepresentation.self)
  var payload: ShelfEvent.Kind
  var at: Date
  var source: String
}

@Table("collections")
struct CollectionRow: Identifiable {
  let id: UUID
  var name: String
  var typeID: String?
  var sortKey: Int
  var createdAt: Date
  var deletedAt: Date?
  @Column(as: ShelfCollection.JSONRepresentation.self)
  var data: ShelfCollection
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
  @Column(as: ShelfObject.JSONRepresentation.self)
  var data: ShelfObject
}

@Table("works")
struct WorkRow: Identifiable {
  let id: UUID
  var title: String
  var typeID: String
  var deletedAt: Date?
  @Column(as: Work.JSONRepresentation.self)
  var data: Work
}

@Table("places")
struct PlaceRow: Identifiable {
  let id: UUID
  var name: String
  var parentID: UUID?
  var createdAt: Date
  var deletedAt: Date?
  @Column(as: Place.JSONRepresentation.self)
  var data: Place
}

@Table("persons")
struct PersonRow: Identifiable {
  let id: UUID
  var name: String
  var lastUsedAt: Date
  var deletedAt: Date?
  @Column(as: Person.JSONRepresentation.self)
  var data: Person
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
  @Column(as: Loan.JSONRepresentation.self)
  var data: Loan
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
          "payload" TEXT NOT NULL,
          "at" TEXT NOT NULL,
          "source" TEXT NOT NULL
        ) STRICT
        """
      )
      .execute(db)
      try #sql(#"CREATE INDEX "index_events_on_objectID" ON "events"("objectID")"#).execute(db)
      try #sql(#"CREATE INDEX "index_events_on_batchID" ON "events"("batchID")"#).execute(db)
      try #sql(#"CREATE INDEX "index_events_on_at_seq" ON "events"("at", "seq")"#).execute(db)
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
    return migrator
  }
}

import Foundation
public import SQLiteData
public import TegolaCatalogue
public import TegolaModel

/// What a command did: its events and the ids it created, for the feature that sent it (PLAN §3.1, step 4).
public struct CommandReceipt: Hashable, Sendable {
  public let events: [ShelfEvent]
  public let batchID: BatchID?

  public var createdObjects: [ObjectID] {
    events.compactMap { event in
      switch event.kind {
      case .added(let object, _): object.id
      case .promoted(_, let copy): copy.id
      default: nil
      }
    }
  }

  public var createdCollections: [CollectionID] {
    events.compactMap { if case .collectionCreated(let collection) = $0.kind { collection.id } else { nil } }
  }
}

/// The one database: the event log and its projection (PLAN §3.1, ADR-0006).
public struct ShelfStore: Sendable {
  public let database: any DatabaseWriter
  public let catalogue: Catalogue

  /// What every connection to the shelf's database needs: `uuid()` for `SyncEngine`'s key defaults, backed by the
  /// `uuid` dependency. The platform's SQLite may not have one (Linux's doesn't).
  public static func configuration(_ base: Configuration = Configuration()) -> Configuration {
    var configuration = base
    configuration.prepareDatabase { db in
      db.add(function: $uuid)
    }
    return configuration
  }

  /// Opens the store and runs the migrations. The database must have been opened with `configuration`.
  public init(database: any DatabaseWriter, catalogue: Catalogue) throws {
    try Self.migrator.migrate(database)
    self.database = database
    self.catalogue = catalogue
  }

  /// Checks a command against the rules, appends its events to the log and applies them to the projection, in one
  /// transaction. A refused command throws `ShelfRuleViolation` and writes nothing.
  @discardableResult
  public func perform(_ command: ShelfCommand, context: PlanContext) throws -> CommandReceipt {
    try database.write { db in
      let before = try Self.loadShelf(db)
      let events = try plan(command, on: before, context: context)
      let after = apply(events, to: before)
      for event in events {
        try EventRow.insert { EventRow(event) }.execute(db)
      }
      try Self.writeChanges(from: before, to: after, at: context.at, db)
      return CommandReceipt(events: events, batchID: events.first?.batchID ?? context.batchID)
    }
  }

  /// The projection, as the model sees it.
  public func shelf() throws -> Shelf {
    try database.read { db in try Self.loadShelf(db) }
  }

  /// The whole log, in order.
  public func log() throws -> [ShelfEvent] {
    try database.read { db in try Self.loadLog(db) }
  }

  /// Whether money shows: off unless the collector turned it on (PD-138).
  public func money() throws -> MoneyVisibility {
    try database.read { db in
      try SettingRow.find(SettingKey.money.id).fetchOne(db).flatMap { MoneyVisibility(rawValue: $0.value) } ?? .off
    }
  }

  /// Stores a setting the collector changed.
  public func set(_ key: SettingKey, to value: String) throws {
    try database.write { db in
      try SettingRow.upsert { SettingRow(id: key.id, key: key.rawValue, value: value) }.execute(db)
    }
  }

  /// An object's events, oldest first: what the History slot reads, before it filters by kind.
  public func history(of object: ObjectID) throws -> [ShelfEvent] {
    try database.read { db in
      try EventRow.where { $0.objectID.eq(object.rawValue) }.order(by: \.seq).fetchAll(db).map {
        try StoredJSON.decode(ShelfEvent.self, from: $0.data)
      }
    }
  }

  /// Recreates the projection from the log, in one transaction. The tables are a derived copy; this is how that's
  /// proved, and how a damaged projection is repaired.
  public func rebuildProjection() throws {
    try database.write { db in
      let log = try Self.loadLog(db)
      try LoanRow.delete().execute(db)
      try PhotoRow.delete().execute(db)
      try ObjectRow.delete().execute(db)
      try CollectionRow.delete().execute(db)
      try WorkRow.delete().execute(db)
      try PlaceRow.delete().execute(db)
      try PersonRow.delete().execute(db)
      try ImportBatchRow.delete().execute(db)
      try Self.writeChanges(from: Shelf(), to: apply(log, to: Shelf()), at: log.last?.at ?? .distantPast, db)
    }
  }

  /// In the order the commands ran. On one device that's `seq`, whatever the clock did; events from several devices
  /// will merge by `at` once sync adds a device column (D-24).
  static func loadLog(_ db: Database) throws -> [ShelfEvent] {
    try EventRow.order(by: \.seq).fetchAll(db).map { try StoredJSON.decode(ShelfEvent.self, from: $0.data) }
  }

  static func loadShelf(_ db: Database) throws -> Shelf {
    var shelf = Shelf()
    for row in try CollectionRow.where({ $0.deletedAt.is(nil) }).fetchAll(db) {
      let value = try StoredJSON.decode(ShelfCollection.self, from: row.data)
      shelf.collections[value.id] = value
    }
    for row in try ObjectRow.where({ $0.deletedAt.is(nil) }).fetchAll(db) {
      let value = try StoredJSON.decode(ShelfObject.self, from: row.data)
      shelf.objects[value.id] = value
    }
    for row in try WorkRow.fetchAll(db) {
      let value = try StoredJSON.decode(Work.self, from: row.data)
      shelf.works[value.id] = value
    }
    for row in try PlaceRow.fetchAll(db) {
      let value = try StoredJSON.decode(Place.self, from: row.data)
      shelf.places[value.id] = value
    }
    for row in try PersonRow.fetchAll(db) {
      let value = try StoredJSON.decode(Person.self, from: row.data)
      shelf.persons[value.id] = value
    }
    for row in try PhotoRow.fetchAll(db) {
      let value = try StoredJSON.decode(Photo.self, from: row.data)
      shelf.photos[value.id] = value
    }
    for row in try LoanRow.fetchAll(db) {
      let value = try StoredJSON.decode(Loan.self, from: row.data)
      shelf.loans[value.id] = value
    }
    for row in try ImportBatchRow.fetchAll(db) {
      let value = try StoredJSON.decode(ImportBatchRecord.self, from: row.data)
      shelf.batches[value.id] = value
    }
    shelf.lastSeq = try EventRow.select { $0.seq.max() }.fetchOne(db).flatMap { $0 } ?? 0
    return shelf
  }

  /// Upserts every row that differs between two shelves, parents before children for the foreign keys. Nothing is
  /// deleted (PD-051, PD-151): what an import's undo removes is marked `deletedAt` and no longer read (D-12).
  static func writeChanges(from before: Shelf, to after: Shelf, at: Date, _ db: Database) throws {
    for (id, value) in after.collections where before.collections[id] != value {
      try CollectionRow.upsert { CollectionRow(value) }.execute(db)
    }
    for (id, value) in after.places where before.places[id] != value {
      try PlaceRow.upsert { PlaceRow(value) }.execute(db)
    }
    for (id, value) in after.persons where before.persons[id] != value {
      try PersonRow.upsert { PersonRow(value) }.execute(db)
    }
    for (id, value) in after.works where before.works[id] != value {
      try WorkRow.upsert { WorkRow(value) }.execute(db)
    }
    for (id, value) in after.objects where before.objects[id] != value {
      try ObjectRow.upsert { ObjectRow(value) }.execute(db)
    }
    for (id, value) in after.photos where before.photos[id] != value {
      try PhotoRow.upsert { PhotoRow(value) }.execute(db)
    }
    for (id, value) in after.loans where before.loans[id] != value {
      try LoanRow.upsert { LoanRow(value) }.execute(db)
    }
    for (id, value) in after.batches where before.batches[id] != value {
      try ImportBatchRow.upsert { ImportBatchRow(value) }.execute(db)
    }
    for id in before.objects.keys where after.objects[id] == nil {
      try ObjectRow.find(id.rawValue).update { $0.deletedAt = #bind(at) }.execute(db)
    }
    for id in before.collections.keys where after.collections[id] == nil {
      try CollectionRow.find(id.rawValue).update { $0.deletedAt = #bind(at) }.execute(db)
    }
  }
}

extension EventRow {
  init(_ event: ShelfEvent) {
    self.init(
      id: event.id.rawValue,
      seq: event.seq,
      objectID: event.objectID?.rawValue,
      batchID: event.batchID?.rawValue,
      kind: event.kind.name,
      at: event.at,
      source: event.source.rawValue,
      data: StoredJSON.encode(event)
    )
  }
}

extension CollectionRow {
  init(_ value: ShelfCollection) {
    self.init(
      id: value.id.rawValue,
      name: value.name,
      typeID: value.typeID?.rawValue,
      sortKey: value.sortKey,
      createdAt: value.createdAt,
      deletedAt: nil,
      data: StoredJSON.encode(value)
    )
  }
}

extension ObjectRow {
  init(_ value: ShelfObject) {
    self.init(
      id: value.id.rawValue,
      collectionID: value.collectionID.rawValue,
      typeID: value.typeID.rawValue,
      subtype: value.subtype,
      workID: value.workID?.rawValue,
      title: value.title,
      placeID: value.placeID?.rawValue,
      quantity: value.quantity,
      ownership: value.ownership.rawValue,
      identity: value.identity.rawValue,
      isGrail: value.isGrail,
      isLetGo: value.letGo != nil,
      createdAt: value.createdAt,
      updatedAt: value.updatedAt,
      deletedAt: nil,
      data: StoredJSON.encode(value)
    )
  }
}

extension WorkRow {
  init(_ value: Work) {
    self.init(
      id: value.id.rawValue,
      title: value.title,
      typeID: value.typeID.rawValue,
      deletedAt: nil,
      data: StoredJSON.encode(value)
    )
  }
}

extension PlaceRow {
  init(_ value: Place) {
    self.init(
      id: value.id.rawValue,
      name: value.name,
      parentID: value.parentID?.rawValue,
      createdAt: value.createdAt,
      deletedAt: nil,
      data: StoredJSON.encode(value)
    )
  }
}

extension PersonRow {
  init(_ value: Person) {
    self.init(
      id: value.id.rawValue,
      name: value.name,
      lastUsedAt: value.lastUsedAt,
      deletedAt: nil,
      data: StoredJSON.encode(value)
    )
  }
}

extension PhotoRow {
  init(_ value: Photo) {
    self.init(
      id: value.id.rawValue,
      objectID: value.objectID.rawValue,
      position: value.position,
      fileName: value.fileName,
      takenAt: value.takenAt,
      deletedAt: nil,
      data: StoredJSON.encode(value)
    )
  }
}

extension ImportBatchRow {
  init(_ value: ImportBatchRecord) {
    self.init(
      id: value.id.rawValue,
      importer: value.importer,
      fileName: value.fileName,
      collectionID: value.collectionID.rawValue,
      rowCount: value.rowCount,
      createdAt: value.at,
      undoneAt: value.undoneAt,
      data: StoredJSON.encode(value)
    )
  }
}

extension LoanRow {
  init(_ value: Loan) {
    self.init(
      id: value.id.rawValue,
      objectID: value.objectID.rawValue,
      personID: value.personID.rawValue,
      direction: value.direction.rawValue,
      dueAt: value.dueAt,
      openedAt: value.openedAt,
      closedAt: value.closedAt,
      deletedAt: nil,
      data: StoredJSON.encode(value)
    )
  }
}

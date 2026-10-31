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

  /// Opens the store and runs the migrations.
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
      try Self.writeChanges(from: before, to: after, db)
      return CommandReceipt(events: events, batchID: context.batchID)
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

  /// An object's events, oldest first: what the History slot reads, before it filters by kind.
  public func history(of object: ObjectID) throws -> [ShelfEvent] {
    try database.read { db in
      try EventRow.where { $0.objectID.eq(object.rawValue) }.order { ($0.at, $0.seq) }.fetchAll(db).map(\.event)
    }
  }

  /// Recreates the projection from the log, in one transaction. The tables are a derived copy; this is how that's
  /// proved, and how a damaged projection is repaired.
  public func rebuildProjection() throws {
    try database.write { db in
      let log = try Self.loadLog(db)
      try LoanRow.delete().execute(db)
      try ObjectRow.delete().execute(db)
      try CollectionRow.delete().execute(db)
      try WorkRow.delete().execute(db)
      try PlaceRow.delete().execute(db)
      try PersonRow.delete().execute(db)
      try Self.writeChanges(from: Shelf(), to: apply(log, to: Shelf()), db)
    }
  }

  static func loadLog(_ db: Database) throws -> [ShelfEvent] {
    try EventRow.order { ($0.at, $0.seq) }.fetchAll(db).map(\.event)
  }

  static func loadShelf(_ db: Database) throws -> Shelf {
    var shelf = Shelf()
    for row in try CollectionRow.fetchAll(db) { shelf.collections[row.data.id] = row.data }
    for row in try ObjectRow.fetchAll(db) { shelf.objects[row.data.id] = row.data }
    for row in try WorkRow.fetchAll(db) { shelf.works[row.data.id] = row.data }
    for row in try PlaceRow.fetchAll(db) { shelf.places[row.data.id] = row.data }
    for row in try PersonRow.fetchAll(db) { shelf.persons[row.data.id] = row.data }
    for row in try LoanRow.fetchAll(db) { shelf.loans[row.data.id] = row.data }
    shelf.lastSeq = try EventRow.select { $0.seq.max() }.fetchOne(db).flatMap { $0 } ?? 0
    return shelf
  }

  /// Upserts every row that differs between two shelves. Nothing is deleted: history only appends, and nothing
  /// leaves the projection (PD-051, PD-151). Parents before children, for the foreign keys.
  static func writeChanges(from before: Shelf, to after: Shelf, _ db: Database) throws {
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
    for (id, value) in after.loans where before.loans[id] != value {
      try LoanRow.upsert { LoanRow(value) }.execute(db)
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
      payload: event.kind,
      at: event.at,
      source: event.source.rawValue
    )
  }

  var event: ShelfEvent {
    ShelfEvent(
      id: EventID(id),
      seq: seq,
      at: at,
      source: ShelfEvent.Source(rawValue: source) ?? .app,
      batchID: batchID.map(BatchID.init),
      kind: payload
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
      data: value
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
      data: value
    )
  }
}

extension WorkRow {
  init(_ value: Work) {
    self.init(id: value.id.rawValue, title: value.title, typeID: value.typeID.rawValue, deletedAt: nil, data: value)
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
      data: value
    )
  }
}

extension PersonRow {
  init(_ value: Person) {
    self.init(id: value.id.rawValue, name: value.name, lastUsedAt: value.lastUsedAt, deletedAt: nil, data: value)
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
      data: value
    )
  }
}

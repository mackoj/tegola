public import SQLiteData
public import TegolaModel

/// What the shelf's screens read: the projection and the money setting, in one transaction. Screens hold it in a
/// `@Fetch`, so they update whenever a command changes the database, and derive what they show with the pure read
/// models (`ShelfSummary`, `CollectionMeta`, `ObjectSlots`).
public struct ShelfSnapshot: Hashable, Sendable {
  public var shelf: Shelf
  public var money: MoneyVisibility

  public init(shelf: Shelf = Shelf(), money: MoneyVisibility = .off) {
    self.shelf = shelf
    self.money = money
  }
}

public struct ShelfRequest: FetchKeyRequest {
  public init() {}

  public func fetch(_ db: Database) throws -> ShelfSnapshot {
    let money = try SettingRow.find(SettingKey.money.id).fetchOne(db).flatMap { MoneyVisibility(rawValue: $0.value) }
    return ShelfSnapshot(shelf: try ShelfStore.loadShelf(db), money: money ?? .off)
  }
}

/// What the object screen reads: the shelf, the money setting and one object's history, oldest first.
public struct ObjectSnapshot: Hashable, Sendable {
  public var shelf: ShelfSnapshot
  public var history: [ShelfEvent]

  public init(shelf: ShelfSnapshot = ShelfSnapshot(), history: [ShelfEvent] = []) {
    self.shelf = shelf
    self.history = history
  }
}

public struct ObjectRequest: FetchKeyRequest {
  public let id: ObjectID

  public init(id: ObjectID) {
    self.id = id
  }

  public func fetch(_ db: Database) throws -> ObjectSnapshot {
    let events = try EventRow.where { $0.objectID.eq(id.rawValue) }.order(by: \.seq).fetchAll(db)
      .map { try StoredJSON.decode(ShelfEvent.self, from: $0.data) }
    return ObjectSnapshot(shelf: try ShelfRequest().fetch(db), history: events)
  }
}

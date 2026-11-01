import Foundation
public import SQLiteData
public import TegolaModel

/// What the shelf's screens read: the projection and the money setting, in one transaction. Screens hold it in a
/// `@Fetch`, so they update whenever a command changes the database, and derive what they show with the pure read
/// models (`ShelfSummary`, `CollectionMeta`, `ObjectSlots`).
public struct ShelfSnapshot: Hashable, Sendable {
  public var shelf: Shelf
  public var money: MoneyVisibility
  /// Where the last object was added, if that collection still exists.
  public var lastCollection: CollectionID?
  /// The answer to the clock notification offer, once given (`accepted`, `declined`).
  public var notificationsOffer: String?
  /// The opt-in clocks the collector turned on.
  public var optedInClocks: Set<String>

  public init(
    shelf: Shelf = Shelf(),
    money: MoneyVisibility = .off,
    lastCollection: CollectionID? = nil,
    notificationsOffer: String? = nil,
    optedInClocks: Set<String> = []
  ) {
    self.shelf = shelf
    self.money = money
    self.lastCollection = lastCollection
    self.notificationsOffer = notificationsOffer
    self.optedInClocks = optedInClocks
  }
}

public struct ShelfRequest: FetchKeyRequest {
  public init() {}

  public func fetch(_ db: Database) throws -> ShelfSnapshot {
    let money = try SettingRow.find(SettingKey.money.id).fetchOne(db).flatMap { MoneyVisibility(rawValue: $0.value) }
    let shelf = try ShelfStore.loadShelf(db)
    let last = try SettingRow.find(SettingKey.lastCollection.id).fetchOne(db)
      .flatMap { UUID(uuidString: $0.value) }.map(CollectionID.init)
    let offer = try SettingRow.find(SettingKey.notificationsOffer.id).fetchOne(db)?.value
    let optedIn = try SettingRow.find(SettingKey.optedInClocks.id).fetchOne(db)?.value ?? ""
    return ShelfSnapshot(
      shelf: shelf,
      money: money ?? .off,
      lastCollection: last.flatMap { shelf.collections[$0] == nil ? nil : $0 },
      notificationsOffer: offer,
      optedInClocks: Set(optedIn.split(separator: ",").map(String.init))
    )
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

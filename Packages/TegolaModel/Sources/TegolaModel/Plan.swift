public import Foundation
public import TegolaCatalogue

/// What `plan` needs besides the command and the shelf: the time, who's acting, the batch, the types, and where new
/// ids come from. The model never reads a clock or makes an id itself (PLAN §2.5).
public struct PlanContext: Sendable {
  public var at: Date
  public var source: ShelfEvent.Source
  public var batchID: BatchID?
  public var catalogue: Catalogue
  public var makeID: @Sendable () -> UUID

  public init(
    at: Date,
    source: ShelfEvent.Source = .collector,
    batchID: BatchID? = nil,
    catalogue: Catalogue,
    makeID: @escaping @Sendable () -> UUID
  ) {
    self.at = at
    self.source = source
    self.batchID = batchID
    self.catalogue = catalogue
    self.makeID = makeID
  }

  func id<Tag>() -> Identifier<Tag> { Identifier(makeID()) }
}

/// A command the rules refuse (PLAN §3.1, step 1). The shelf is unchanged.
public enum ShelfRuleViolation: Error, Hashable, Sendable {
  case unknownObject(ObjectID)
  case unknownCollection(CollectionID)
  case unknownLoan(LoanID)
  case unknownPerson(PersonID)
  case unknownType(TypeManifest.ID)
  case unknownSubtype(TypeManifest.ID, String)
  /// A key the object's type, subtype and item level don't have.
  case unknownField(FieldKey)
  /// Only the collector may do this: confirm, edit (PD-042, PD-045).
  case collectorOnly
  case emptyName
  /// An object needs a title, unless it's a photo with nothing identified yet.
  case emptyTitle
  /// A typed collection only takes its own type.
  case wrongType(collection: CollectionID, type: TypeManifest.ID)
  /// A wanted object has no condition: you can't grade what you don't have.
  case wantedHasNoCondition
  /// A rows object is one copy; only a quantity object counts (PD-020).
  case rowsAreOneCopy
  /// A quantity object can't be lent until a copy is promoted (PD-020, PD-121).
  case quantityCantBeLent
  case notAQuantity
  case quantityBelowZero
  case notOwned
  case notWanted
  case alreadyLetGo
  case alreadyOnLoan
  case notOnLoan
}

/// Turns a command into the events that carry it out, or refuses it. Pure: the same command on the same shelf with
/// the same context gives the same events (PLAN §3.1, step 2).
public func plan(
  _ command: ShelfCommand,
  on shelf: Shelf,
  context: PlanContext
) throws(ShelfRuleViolation) -> [ShelfEvent] {
  var planner = Planner(shelf: shelf, context: context)
  try planner.plan(command)
  return planner.events
}

/// Applies events to a shelf: the projection (PLAN §3.1, step 3). Events are applied as they come; `plan` has already
/// checked them, and replaying the log rebuilds the same shelf.
public func apply(_ events: [ShelfEvent], to shelf: Shelf) -> Shelf {
  var shelf = shelf
  for event in events { shelf.apply(event) }
  return shelf
}

struct Planner {
  var shelf: Shelf
  let context: PlanContext
  var events: [ShelfEvent] = []

  /// Records an event and applies it, so later events in the same command see it (a place made on the way).
  mutating func emit(_ kind: ShelfEvent.Kind) {
    let event = ShelfEvent(
      id: context.id(),
      seq: shelf.lastSeq + 1,
      at: context.at,
      source: context.source,
      batchID: context.batchID,
      kind: kind
    )
    shelf.apply(event)
    events.append(event)
  }

  func object(_ id: ObjectID) throws(ShelfRuleViolation) -> ShelfObject {
    guard let object = shelf.objects[id] else { throw .unknownObject(id) }
    return object
  }

  func requireCollector() throws(ShelfRuleViolation) {
    guard context.source == .collector else { throw .collectorOnly }
  }

  mutating func plan(_ command: ShelfCommand) throws(ShelfRuleViolation) {
    switch command {
    case .createCollection(let name, let type):
      _ = try createCollection(name: name, type: type)
    case .add(let draft, let choice, let origin):
      try add(draft, to: choice, origin: origin)
    case .confirm(let ids):
      try requireCollector()
      for id in ids where try object(id).identity != .confirmed {
        if try object(id).title.isEmpty { throw .emptyTitle }
        emit(.confirmed(id))
      }
    case .edit(let id, let values):
      try edit(id, values: values)
    case .applyLookup(let id, let values):
      let object = try object(id)
      try checkKeys(values.keys, on: object)
      // Promise 1: a lookup fills empty keys and keys it filled itself, never one the collector typed (PD-045).
      let changes = values.filter { key, value in
        (object.values[key] == nil || object.auto.contains(key)) && object.values[key] != value
      }
      if !changes.isEmpty { emit(.enriched(id, changes: changes)) }
    case .setPlace(let ids, let path):
      let placeID = path.map { place(at: $0) }
      for id in ids where try object(id).placeID != placeID {
        emit(.placed(id, placeID))
      }
    case .logEvent(let id, let kind, let note):
      _ = try object(id)
      emit(.logged(id, kind: kind, note: note))
    case .lend(let id, let choice, let due, let note):
      try lend(id, to: choice, due: due, note: note)
    case .returnLoan(let loanID, let condition):
      guard let loan = shelf.loans[loanID] else { throw .unknownLoan(loanID) }
      guard loan.isOpen, loan.direction == .out else { throw .notOnLoan }
      emit(.returned(loanID, objectID: loan.objectID, condition: condition))
    case .markBorrowed(let id, let choice):
      let object = try object(id)
      guard object.letGo == nil else { throw .alreadyLetGo }
      guard shelf.openLoan(on: id) == nil else { throw .alreadyOnLoan }
      let personID = try person(choice)
      emit(.borrowed(loan(id, personID, direction: .in, due: nil, note: "")))
    case .giveBack(let id):
      _ = try object(id)
      guard let loan = shelf.openLoan(on: id), loan.direction == .in else { throw .notOnLoan }
      emit(.gaveBack(loan.id, objectID: id))
    case .setOwned(let id):
      let object = try object(id)
      guard object.ownership != .owned else { return }
      guard object.letGo == nil else { throw .alreadyLetGo }
      if let loan = shelf.openLoan(on: id), loan.direction == .in { throw .alreadyOnLoan }
      emit(.ownershipChanged(id, .owned))
    case .setWanted(let id, let priority, let priceCap):
      guard try object(id).ownership == .wanted else { throw .notWanted }
      emit(.wanted(id, priority: priority, priceCap: priceCap))
    case .setGrail(let id, let isGrail):
      if try object(id).isGrail != isGrail { emit(.grailChanged(id, isGrail)) }
    case .setMightLetGo(let id, let mightLetGo):
      let object = try object(id)
      guard object.ownership == .owned, object.letGo == nil else { throw .notOwned }
      if object.mightLetGo != mightLetGo { emit(.mightLetGoChanged(id, mightLetGo)) }
    case .letGo(let id, let reason):
      let object = try object(id)
      guard object.letGo == nil else { throw .alreadyLetGo }
      guard object.ownership == .owned else { throw .notOwned }
      guard shelf.openLoan(on: id) == nil else { throw .alreadyOnLoan }
      emit(.letGo(id, LetGo(reason: reason, at: context.at)))
    case .promote(let id):
      try promote(id)
    case .adjustQuantity(let id, let delta):
      let object = try object(id)
      guard object.bulk == .quantity else { throw .notAQuantity }
      guard object.quantity + delta >= 0 else { throw .quantityBelowZero }
      if delta != 0 { emit(.quantityAdjusted(id, by: delta)) }
    case .renameCollection(let id, let name):
      guard shelf.collections[id] != nil else { throw .unknownCollection(id) }
      let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { throw .emptyName }
      emit(.collectionRenamed(id, name: name))
    case .moveObjects(let ids, let collectionID):
      guard let collection = shelf.collections[collectionID] else { throw .unknownCollection(collectionID) }
      for id in ids {
        let object = try object(id)
        if let type = collection.typeID, type != object.typeID {
          throw .wrongType(collection: collectionID, type: object.typeID)
        }
        if object.collectionID != collectionID { emit(.moved(id, to: collectionID)) }
      }
    }
  }

  mutating func createCollection(name: String, type: TypeManifest.ID?) throws(ShelfRuleViolation) -> CollectionID {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw .emptyName }
    if let type, context.catalogue.manifest(type) == nil { throw .unknownType(type) }
    let id: CollectionID = context.id()
    let sortKey = (shelf.collections.values.map(\.sortKey).max() ?? -1) + 1
    emit(
      .collectionCreated(
        ShelfCollection(id: id, name: name, typeID: type, purpose: nil, sortKey: sortKey, createdAt: context.at)
      )
    )
    return id
  }

  func effectiveType(_ type: TypeManifest.ID, _ subtype: String?) throws(ShelfRuleViolation) -> EffectiveType {
    do {
      return try context.catalogue.resolve(type, subtype: subtype)
    } catch {
      switch error {
      case .unknownType(let type): throw .unknownType(type)
      case .unknownSubtype(let type, let subtype): throw .unknownSubtype(type, subtype)
      }
    }
  }

  /// Every key must belong to the object's spine, condition, notes, or its effective type's fields (scale fields for
  /// a ladder axis).
  func checkKeys(_ keys: some Sequence<FieldKey>, type: EffectiveType) throws(ShelfRuleViolation) {
    for key in keys {
      switch key {
      case .title, .subtitle, .year, .acquired, .paid, .value, .condition, .notes: continue
      case .field(let name):
        if type.field(name) == nil { throw .unknownField(key) }
      case .axis(let name):
        if type.field(name)?.field.kind != .scale { throw .unknownField(key) }
      }
    }
  }

  func checkKeys(_ keys: some Sequence<FieldKey>, on object: ShelfObject) throws(ShelfRuleViolation) {
    try checkKeys(keys, type: try effectiveType(object.typeID, object.subtype))
  }

  static func hasCondition(_ keys: some Sequence<FieldKey>) -> Bool {
    keys.contains { key in
      if case .axis = key { return true }
      return key == .condition
    }
  }

  mutating func add(_ draft: ObjectDraft, to choice: CollectionChoice, origin: AddOrigin) throws(ShelfRuleViolation) {
    let type = try effectiveType(draft.type, draft.subtype)
    try checkKeys(draft.values.keys, type: type)
    guard let manifest = context.catalogue.manifest(draft.type) else { throw .unknownType(draft.type) }
    if draft.ownership == .wanted && Self.hasCondition(draft.values.keys) { throw .wantedHasNoCondition }
    let hasTitle: Bool
    if case .text(let title) = draft.values[.title] {
      hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    } else {
      hasTitle = false
    }
    let needsDetails = origin == .captured && draft.needsDetails
    guard hasTitle || needsDetails else { throw .emptyTitle }
    let bulk: ShelfObject.Bulk =
      switch manifest.duplicates {
      case .rows: .rows
      case .quantity: .quantity
      case .ask: draft.bulk ?? .rows
      }
    if bulk == .rows && draft.quantity != 1 { throw .rowsAreOneCopy }
    if draft.quantity < 1 { throw .quantityBelowZero }

    let collectionID: CollectionID
    switch choice {
    case .existing(let id):
      guard let collection = shelf.collections[id] else { throw .unknownCollection(id) }
      if let typeID = collection.typeID, typeID != draft.type { throw .wrongType(collection: id, type: draft.type) }
      collectionID = id
    case .new(let name):
      collectionID = try createCollection(name: name, type: draft.type)
    }

    // Promise 8: only the collector's own words confirm. A capture is a guess until they agree (PD-042).
    let identity: ShelfObject.Identity =
      switch origin {
      case .typed, .firstPiece, .imported: .confirmed
      case .captured: needsDetails ? .needsDetails : .unconfirmed
      }
    // Promise 7: the values are the draft's. The app never fills `acquired` (PD-165).
    let object = ShelfObject(
      id: context.id(),
      collectionID: collectionID,
      typeID: draft.type,
      subtype: draft.subtype,
      workID: nil,
      values: draft.values,
      auto: [],
      placeID: nil,
      bulk: bulk,
      quantity: draft.quantity,
      ownership: draft.ownership,
      identity: identity,
      isGrail: false,
      mightLetGo: false,
      priority: nil,
      priceCap: nil,
      letGo: nil,
      promotedFrom: nil,
      createdAt: context.at,
      updatedAt: context.at
    )
    emit(.added(object, origin: origin))
  }

  mutating func edit(_ id: ObjectID, values: [FieldKey: FieldValue?]) throws(ShelfRuleViolation) {
    try requireCollector()
    let object = try object(id)
    try checkKeys(values.keys, on: object)
    let changes = values.filter { key, value in object.values[key] != value }
    if object.ownership == .wanted && Self.hasCondition(changes.compactMap { $0.value == nil ? nil : $0.key }) {
      throw .wantedHasNoCondition
    }
    if let title = changes[.title] {
      guard case .text(let text) = title, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw .emptyTitle
      }
    }
    if !changes.isEmpty { emit(.edited(id, changes: changes)) }
  }

  mutating func lend(_ id: ObjectID, to choice: PersonChoice, due: Date?, note: String) throws(ShelfRuleViolation) {
    let object = try object(id)
    // Promise 6: a count can't be lent; a promoted copy can (PD-020, PD-121).
    guard object.bulk == .rows else { throw .quantityCantBeLent }
    guard object.letGo == nil else { throw .alreadyLetGo }
    guard object.ownership == .owned else { throw .notOwned }
    guard shelf.openLoan(on: id) == nil else { throw .alreadyOnLoan }
    let personID = try person(choice)
    emit(.lent(loan(id, personID, direction: .out, due: due, note: note)))
  }

  mutating func promote(_ id: ObjectID) throws(ShelfRuleViolation) {
    let object = try object(id)
    guard object.bulk == .quantity else { throw .notAQuantity }
    guard object.quantity >= 1 else { throw .quantityBelowZero }
    guard object.letGo == nil else { throw .alreadyLetGo }
    let copy = ShelfObject(
      id: context.id(),
      collectionID: object.collectionID,
      typeID: object.typeID,
      subtype: object.subtype,
      workID: object.workID,
      values: object.values,
      auto: object.auto,
      placeID: object.placeID,
      bulk: .rows,
      quantity: 1,
      ownership: object.ownership,
      identity: object.identity,
      isGrail: false,
      mightLetGo: false,
      priority: nil,
      priceCap: nil,
      letGo: nil,
      promotedFrom: object.id,
      createdAt: context.at,
      updatedAt: context.at
    )
    emit(.promoted(from: id, copy: copy))
  }

  mutating func person(_ choice: PersonChoice) throws(ShelfRuleViolation) -> PersonID {
    switch choice {
    case .existing(let id):
      guard shelf.persons[id] != nil else { throw .unknownPerson(id) }
      return id
    case .new(let name):
      let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { throw .emptyName }
      let id: PersonID = context.id()
      emit(.personCreated(Person(id: id, name: name, lastUsedAt: context.at)))
      return id
    }
  }

  func loan(_ object: ObjectID, _ person: PersonID, direction: Loan.Direction, due: Date?, note: String) -> Loan {
    Loan(
      id: context.id(),
      objectID: object,
      personID: person,
      direction: direction,
      dueAt: due,
      note: note,
      openedAt: context.at,
      closedAt: nil,
      closedBy: nil,
      returnCondition: nil
    )
  }

  /// The place a path names, made on the way where it doesn't exist yet (PD-053). An existing place is matched by
  /// name under the same parent; duplicates made on two devices are merged by the collector, never here.
  mutating func place(at path: PlacePath) -> PlaceID {
    var parent: PlaceID?
    for name in path.components {
      let existing = shelf.places.values
        .filter { $0.parentID == parent && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        .min { $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt }
      if let existing {
        parent = existing.id
      } else {
        let id: PlaceID = context.id()
        emit(.placeCreated(Place(id: id, name: name, parentID: parent, createdAt: context.at)))
        parent = id
      }
    }
    return parent!
  }
}

extension Shelf {
  /// One event's effect on the projection.
  mutating func apply(_ event: ShelfEvent) {
    lastSeq = max(lastSeq, event.seq)
    let at = event.at
    func touch(_ id: ObjectID, _ change: (inout ShelfObject) -> Void) {
      guard var object = objects[id] else { return }
      change(&object)
      object.updatedAt = at
      objects[id] = object
    }
    switch event.kind {
    case .collectionCreated(let collection): collections[collection.id] = collection
    case .collectionRenamed(let id, let name): collections[id]?.name = name
    case .placeCreated(let place): places[place.id] = place
    case .personCreated(let person): persons[person.id] = person
    case .workCreated(let work): works[work.id] = work
    case .added(let object, _): objects[object.id] = object
    case .edited(let id, let changes):
      touch(id) { object in
        for (key, value) in changes {
          object.values[key] = value
          // The collector touched it, so it's theirs now: no AUTO badge, and no lookup changes it again.
          object.auto.remove(key)
        }
      }
    case .enriched(let id, let changes):
      touch(id) { object in
        for (key, value) in changes {
          object.values[key] = value
          object.auto.insert(key)
        }
      }
    case .confirmed(let id): touch(id) { $0.identity = .confirmed }
    case .placed(let id, let place): touch(id) { $0.placeID = place }
    case .moved(let id, let collection): touch(id) { $0.collectionID = collection }
    case .lent(let loan):
      loans[loan.id] = loan
      persons[loan.personID]?.lastUsedAt = at
    case .borrowed(let loan):
      loans[loan.id] = loan
      persons[loan.personID]?.lastUsedAt = at
      touch(loan.objectID) { $0.ownership = .borrowed }
    case .returned(let id, _, let condition):
      loans[id]?.closedAt = at
      loans[id]?.closedBy = .collector
      loans[id]?.returnCondition = condition
    case .gaveBack(let id, _):
      loans[id]?.closedAt = at
      loans[id]?.closedBy = .collector
    case .logged(let id, _, _): touch(id) { _ in }
    case .ownershipChanged(let id, let ownership): touch(id) { $0.ownership = ownership }
    case .wanted(let id, let priority, let priceCap):
      touch(id) { object in
        object.priority = priority
        object.priceCap = priceCap
      }
    case .grailChanged(let id, let isGrail): touch(id) { $0.isGrail = isGrail }
    case .mightLetGoChanged(let id, let mightLetGo): touch(id) { $0.mightLetGo = mightLetGo }
    case .letGo(let id, let letGo): touch(id) { $0.letGo = letGo }
    case .promoted(let id, let copy):
      touch(id) { $0.quantity -= 1 }
      objects[copy.id] = copy
    case .quantityAdjusted(let id, let delta): touch(id) { $0.quantity += delta }
    }
  }
}

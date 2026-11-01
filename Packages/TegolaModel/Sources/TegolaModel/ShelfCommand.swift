public import Foundation
public import TegolaCatalogue

/// Every change to the shelf, as a value (PLAN §3.1). `ShelfClient.perform` checks one against the rules, turns it into
/// events with `plan`, appends them and updates the projection in one transaction. Each case cites the decision that
/// defines it.
public enum ShelfCommand: Hashable, Sendable {
  case createCollection(name: String, type: TypeManifest.ID?)
  /// PD-137, PD-165, PD-166.
  case add(ObjectDraft, to: CollectionChoice, origin: AddOrigin)
  /// PD-042: only a collector confirms.
  case confirm([ObjectID])
  /// The edit form's Save: the values as the form holds them. `plan` keeps the changed keys only (PD-050).
  case edit(ObjectID, values: [FieldKey: FieldValue?])
  /// A lookup's result: fills empty keys and keys it filled before, never a typed one (PD-042, PD-045).
  case applyLookup(ObjectID, values: [FieldKey: FieldValue])
  /// A photo the photo store has saved (PD-053's sibling: the object's own picture). The file is written first;
  /// the command records it.
  case attachPhoto(ObjectID, fileName: String, takenAt: Date)
  /// PD-053: typing a place creates the nested places it names.
  case setPlace([ObjectID], PlacePath?)
  /// Story 54.
  case logEvent(ObjectID, kind: String, note: String)
  /// F15, risk R2: the collector says a signal's wrong or not worth it. It holds until the reading gets worse or what
  /// the clock reads changes (D-60).
  case dismissSignal(ObjectID, Signal)
  /// PD-123, PD-148.
  case lend(ObjectID, to: PersonChoice, due: Date?, note: String)
  /// PD-148, PD-160: closed by the collector alone without a backend (D-2).
  case returnLoan(LoanID, condition: String?)
  /// PD-061.
  case markBorrowed(ObjectID, from: PersonChoice)
  case giveBack(ObjectID)
  /// PD-070, PD-126.
  case setOwned(ObjectID)
  case setWanted(ObjectID, priority: Int?, priceCap: Money?)
  case setGrail(ObjectID, Bool)
  case setMightLetGo(ObjectID, Bool)
  /// PD-149.
  case letGo(ObjectID, LetGo.Reason)
  /// PD-020, PD-021.
  case promote(ObjectID)
  case adjustQuantity(ObjectID, by: Int)
  /// Stories 83, 109.
  case renameCollection(CollectionID, name: String)
  case moveObjects([ObjectID], to: CollectionID)
  /// Story 109: a near-duplicate place folds into the one the collector keeps.
  case mergePlaces(PlaceID, into: PlaceID)
  // Not yet: openBottle (wine isn't a v1 type),
  // importBatch and undoBatch (M6). `plan` doesn't know them, so a screen can't send them.
}

/// A new object as a form, a capture or an import row describes it.
public struct ObjectDraft: Hashable, Sendable {
  public var type: TypeManifest.ID
  public var subtype: String?
  public var values: [FieldKey: FieldValue]
  public var ownership: ShelfObject.Ownership
  /// Thing asks how duplicates count (PD-151); every other type says, and this is ignored.
  public var bulk: ShelfObject.Bulk?
  public var quantity: Int
  /// For a capture: nothing could be identified, so the object needs details (CONTEXT: Needs details).
  public var needsDetails: Bool
  /// A piece recognised as a type that hasn't shipped is saved as a Thing that waits for it (D-63).
  public var awaitingType: TypeManifest.ID?

  public init(
    type: TypeManifest.ID,
    subtype: String? = nil,
    values: [FieldKey: FieldValue] = [:],
    ownership: ShelfObject.Ownership = .owned,
    bulk: ShelfObject.Bulk? = nil,
    quantity: Int = 1,
    needsDetails: Bool = false,
    awaitingType: TypeManifest.ID? = nil
  ) {
    self.type = type
    self.subtype = subtype
    self.values = values
    self.ownership = ownership
    self.bulk = bulk
    self.quantity = quantity
    self.needsDetails = needsDetails
    self.awaitingType = awaitingType
  }

  /// A piece the collector or a guess said is `type`. A type that hasn't shipped becomes a Thing waiting for it
  /// (46, 2B; D-63), keeping only what every type means the same way: the title, the maker, the year and the notes.
  public static func recognised(
    as type: TypeManifest.ID,
    subtype: String? = nil,
    values: [FieldKey: FieldValue],
    catalogue: Catalogue
  ) -> ObjectDraft {
    if Catalogue.enabledInV1.contains(type) {
      return ObjectDraft(type: type, subtype: subtype, values: values)
    }
    let spine = values.filter { [.title, .subtitle, .year, .notes].contains($0.key) }
    return ObjectDraft(type: "thing", values: spine, awaitingType: catalogue.manifest(type) == nil ? nil : type)
  }
}

/// Where a new object goes: an existing collection, or the type's first collection, made on the way (PD-137).
public enum CollectionChoice: Hashable, Sendable {
  case existing(CollectionID)
  case new(name: String)
}

extension ShelfCommand {
  /// The onboarding's one write (PLAN F2): the piece, in the collection its type names, which the collector never
  /// created (PD-137), with how it came to them as its first history line (PD-166). Never `acquired` (PD-165).
  public static func firstPiece(_ draft: ObjectDraft, story: String, catalogue: Catalogue) -> ShelfCommand {
    let name = catalogue.manifest(draft.type)?.name.collection ?? draft.type.rawValue
    return .add(draft, to: .new(name: name), origin: .firstPiece(story: story))
  }
}

/// Who a loan is with: someone already on the shelf, or a name typed for the first time (CONTEXT: Person).
public enum PersonChoice: Hashable, Sendable {
  case existing(PersonID)
  case new(name: String)
}

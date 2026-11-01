public import Foundation

/// One change to the shelf. The event log is the source of truth (page 52: "every change is an event; current state
/// is derived from it"), and it only grows (PD-051). A collector's History slot is an object's events, filtered to the
/// kinds a person reads (PLAN §3.2).
public struct ShelfEvent: Hashable, Sendable, Codable, Identifiable {
  /// Who caused the change. Only `collector` may confirm, or change a value the collector typed (PD-042, PD-045).
  public enum Source: String, Hashable, Sendable, Codable {
    case collector, capture, lookup, `import`, app
  }

  public let id: EventID
  /// Per device, one more than the last event's. Events order by `at`, then `seq` (D-24).
  public let seq: Int
  public let at: Date
  public let source: Source
  /// The import or migration this event belongs to: undone together (PD-047).
  public let batchID: BatchID?
  public let kind: Kind

  public init(id: EventID, seq: Int, at: Date, source: Source, batchID: BatchID?, kind: Kind) {
    self.id = id
    self.seq = seq
    self.at = at
    self.source = source
    self.batchID = batchID
    self.kind = kind
  }

  /// The object the event is about, for the History slot and the log's index.
  public var objectID: ObjectID? { kind.objectID }

  public enum Kind: Hashable, Sendable, Codable {
    case collectionCreated(ShelfCollection)
    case collectionRenamed(CollectionID, name: String)
    case placeCreated(Place)
    case personCreated(Person)
    case workCreated(Work)
    /// An object joins the shelf, in its first state.
    case added(ShelfObject, origin: AddOrigin)
    /// The collector changed these values (the edit form's Save, or filling in an unconfirmed object). Only the
    /// changed keys; a nil value clears one.
    case edited(ObjectID, changes: [FieldKey: FieldValue?])
    /// A lookup filled these values. Only empty keys, or keys it filled before and nobody touched (PD-045).
    case enriched(ObjectID, changes: [FieldKey: FieldValue])
    case confirmed(ObjectID)
    case placed(ObjectID, PlaceID?)
    /// Two places were one: `from` folds into `into`, its children with it (story 109).
    case placesMerged(from: PlaceID, into: PlaceID)
    case photoAttached(Photo)
    case moved(ObjectID, to: CollectionID)
    case lent(Loan)
    case borrowed(Loan)
    /// `cameBack` is nil in events written before M7 (T7.2) and when the collector didn't say.
    case returned(LoanID, objectID: ObjectID, condition: String?, cameBack: Loan.CameBack? = nil)
    case gaveBack(LoanID, objectID: ObjectID)
    /// Something done to the object, in the collector's words: serviced, cleaned, played.
    case logged(ObjectID, kind: String, note: String)
    /// A signal dismissed, with what it read and the parameters in force, so the clocks can be tuned (risk R2, D-60).
    case signalDismissed(ObjectID, SignalDismissal)
    case ownershipChanged(ObjectID, ShelfObject.Ownership)
    case wanted(ObjectID, priority: Int?, priceCap: Money?)
    case grailChanged(ObjectID, Bool)
    case mightLetGoChanged(ObjectID, Bool)
    case letGo(ObjectID, LetGo)
    /// One copy leaves a quantity object as an object of its own (PD-020).
    case promoted(from: ObjectID, copy: ShelfObject)
    case quantityAdjusted(ObjectID, by: Int)
    /// An import's record; its rows follow as `added` events carrying its batch id.
    case batchImported(ImportBatchRecord)
    /// An import undone: the objects it removed, and the ones kept because the collector had changed them (D-12).
    case batchUndone(BatchID, removed: [ObjectID], kept: [ObjectID])

    /// The kind's name, as the log's `kind` column stores it. The History slot filters on it (PLAN §3.2).
    public var name: String {
      switch self {
      case .collectionCreated: "collectionCreated"
      case .collectionRenamed: "collectionRenamed"
      case .placeCreated: "placeCreated"
      case .personCreated: "personCreated"
      case .workCreated: "workCreated"
      case .added: "added"
      case .edited: "edited"
      case .enriched: "enriched"
      case .confirmed: "confirmed"
      case .placed: "placed"
      case .placesMerged: "placesMerged"
      case .photoAttached: "photo"
      case .moved: "moved"
      case .lent: "lent"
      case .borrowed: "borrowed"
      case .returned: "returned"
      case .gaveBack: "gaveBack"
      case .logged: "logged"
      case .signalDismissed: "signalDismissed"
      case .ownershipChanged: "owned"
      case .wanted: "wanted"
      case .grailChanged: "grail"
      case .mightLetGoChanged: "mightLetGo"
      case .letGo: "letGo"
      case .promoted: "promoted"
      case .quantityAdjusted: "quantityAdjusted"
      case .batchImported: "batchImported"
      case .batchUndone: "batchUndone"
      }
    }

    /// Whether the History slot shows it: the kinds a person reads (PLAN §3.2). Flags that only steer screens
    /// (grail, might let go, a wishlist priority, a count's adjustment) aren't history.
    public var readsAsHistory: Bool {
      switch self {
      case .added, .edited, .enriched, .confirmed, .placed, .photoAttached, .moved, .lent, .borrowed, .returned,
        .gaveBack, .logged,
        .ownershipChanged, .letGo, .promoted:
        true
      case .collectionCreated, .collectionRenamed, .placeCreated, .personCreated, .workCreated, .placesMerged, .wanted,
        .grailChanged,
        .mightLetGoChanged, .quantityAdjusted, .signalDismissed, .batchImported, .batchUndone:
        false
      }
    }

    public var objectID: ObjectID? {
      switch self {
      case .collectionCreated, .collectionRenamed, .placeCreated, .personCreated, .workCreated, .placesMerged,
        .batchImported, .batchUndone:
        nil
      case .added(let object, _): object.id
      case .edited(let id, _), .enriched(let id, _), .confirmed(let id), .placed(let id, _), .moved(let id, _),
        .logged(let id, _, _), .signalDismissed(let id, _), .ownershipChanged(let id, _), .wanted(let id, _, _),
        .grailChanged(let id, _),
        .mightLetGoChanged(let id, _), .letGo(let id, _), .quantityAdjusted(let id, _):
        id
      case .lent(let loan), .borrowed(let loan): loan.objectID
      case .photoAttached(let photo): photo.objectID
      case .returned(_, let id, _, _), .gaveBack(_, let id): id
      case .promoted(let id, _): id
      }
    }
  }
}

/// How an object arrived (PD-137, PD-165, PD-166).
public enum AddOrigin: Hashable, Sendable, Codable {
  /// Typed by the collector: confirmed from the start.
  case typed
  /// From the camera: unconfirmed, or needs details when nothing was identified.
  case captured
  /// From a list the collector brought: unconfirmed until they look (PD-047).
  case imported
  /// The onboarding's first piece, with the story the collector told (46).
  case firstPiece(story: String)
}

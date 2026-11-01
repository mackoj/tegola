public import Foundation
public import TegolaCatalogue

/// One physical thing owned, wanted or held for someone else (CONTEXT: Object). This is the projection's row: its
/// state after every event so far, never written except by `apply`.
public struct ShelfObject: Hashable, Sendable, Codable, Identifiable {
  public enum Ownership: String, Hashable, Sendable, Codable, CaseIterable {
    case owned, wanted, borrowed
  }

  /// Whether the collector has agreed what this is (PD-042). Only a collector's action confirms.
  public enum Identity: String, Hashable, Sendable, Codable, CaseIterable {
    case confirmed, unconfirmed, needsDetails
  }

  /// Rows: each copy is an object. Quantity: a count on one object, which can't be lent until a copy is promoted
  /// (PD-020, PD-121).
  public enum Bulk: String, Hashable, Sendable, Codable {
    case rows, quantity
  }

  public let id: ObjectID
  public var collectionID: CollectionID
  public let typeID: TypeManifest.ID
  public var subtype: String?
  public var workID: WorkID?
  /// Every value the object has, spine included, by key.
  public var values: [FieldKey: FieldValue]
  /// Keys a lookup filled and the collector hasn't touched since: badged AUTO, and the only ones a lookup may
  /// change again (PD-042, PD-045).
  public var auto: Set<FieldKey>
  /// Keys the collector has typed or cleared. A lookup never fills one again, even once it's empty (promise 1).
  public var typed: Set<FieldKey>
  public var placeID: PlaceID?
  public let bulk: Bulk
  public var quantity: Int
  public var ownership: Ownership
  public var identity: Identity
  public var isGrail: Bool
  public var mightLetGo: Bool
  public var priority: Int?
  public var priceCap: Money?
  public var letGo: LetGo?
  /// The copy this one was promoted from, for a quantity object's copy (PD-020).
  public let promotedFrom: ObjectID?
  public let createdAt: Date
  public var updatedAt: Date
  /// What the clocks read beyond the values: the last service and backup, and since when it's been Playing. Kept by
  /// `apply` from the events, so a signal needs no history (D-59). Absent until a clock has something to read.
  public var signalState: SignalState? = nil

  public var title: String {
    if case .text(let title) = values[.title] { title } else { "" }
  }

  /// Wanted, borrowed and let-go objects never count (PD-061, PD-070).
  public var counts: Bool { ownership == .owned && letGo == nil }

  public var acquiredAt: Date? {
    if case .date(let date) = values[.acquired] { date } else { nil }
  }
}

/// Leaving the shelf for good, with a reason; kept in the archive (PD-149).
public struct LetGo: Hashable, Sendable, Codable {
  public enum Reason: Hashable, Sendable, Codable {
    case sold(price: Money?)
    case gifted, traded, lost, broken
  }

  public let reason: Reason
  public let at: Date
}

/// A named group of objects, usually of one type; a mixed collection has none (CONTEXT: Collection).
public struct ShelfCollection: Hashable, Sendable, Codable, Identifiable {
  public let id: CollectionID
  public var name: String
  public let typeID: TypeManifest.ID?
  /// What the collection is for, in the collector's words (story 196).
  public var purpose: String?
  public var sortKey: Int
  public let createdAt: Date
}

/// One work, many objects: Doom on six platforms, a film on three formats.
public struct Work: Hashable, Sendable, Codable, Identifiable {
  public let id: WorkID
  public var title: String
  public let typeID: TypeManifest.ID
  /// Wikidata, IGDB, MusicBrainz, BoardGameGeek, Discogs ids, by provider.
  public var externalIDs: [String: String]
}

/// A physical location, created by typing, nested with `›` (CONTEXT: Place).
public struct Place: Hashable, Sendable, Codable, Identifiable {
  public let id: PlaceID
  public var name: String
  public var parentID: PlaceID?
  public let createdAt: Date
  /// Set when the collector merged this place into another: it stays in the projection, out of every list.
  public var mergedInto: PlaceID?

  public init(id: PlaceID, name: String, parentID: PlaceID?, createdAt: Date, mergedInto: PlaceID? = nil) {
    self.id = id
    self.name = name
    self.parentID = parentID
    self.createdAt = createdAt
    self.mergedInto = mergedInto
  }
}

/// Someone you lend to or borrow from, created by typing a name (CONTEXT: Person).
public struct Person: Hashable, Sendable, Codable, Identifiable {
  public let id: PersonID
  public var name: String
  public var lastUsedAt: Date
}

/// An object lent to a person, or borrowed from one (CONTEXT: Loan).
public struct Loan: Hashable, Sendable, Codable, Identifiable {
  public enum Direction: String, Hashable, Sendable, Codable {
    /// Lent out: the collector's object is with someone.
    case out
    /// Borrowed in: someone's object is on the shelf.
    case `in`
  }

  /// Who closed it. Without a backend, only the collector can (D-2, PD-160).
  public enum ClosedBy: String, Hashable, Sendable, Codable {
    case collector, both
  }

  public let id: LoanID
  public let objectID: ObjectID
  public let personID: PersonID
  public let direction: Direction
  public var dueAt: Date?
  public var note: String
  public let openedAt: Date
  public var closedAt: Date?
  public var closedBy: ClosedBy?
  /// The condition it came back in, when the collector says (PD-148).
  public var returnCondition: String?

  public var isOpen: Bool { closedAt == nil }
}

/// A photo of an object. The image is a file outside the database; this is its row (PLAN §3.2).
public struct Photo: Hashable, Sendable, Codable, Identifiable {
  public let id: PhotoID
  public let objectID: ObjectID
  /// Order on the object: 0 is the hero.
  public let position: Int
  /// The file's name in the photo store.
  public let fileName: String
  public let takenAt: Date

  public init(id: PhotoID, objectID: ObjectID, position: Int, fileName: String, takenAt: Date) {
    self.id = id
    self.objectID = objectID
    self.position = position
    self.fileName = fileName
    self.takenAt = takenAt
  }
}

/// The projection: current state, derived from the event log by `apply` (PLAN §3.1).
public struct Shelf: Hashable, Sendable, Codable {
  public var collections: [CollectionID: ShelfCollection] = [:]
  public var objects: [ObjectID: ShelfObject] = [:]
  public var works: [WorkID: Work] = [:]
  public var places: [PlaceID: Place] = [:]
  public var persons: [PersonID: Person] = [:]
  public var loans: [LoanID: Loan] = [:]
  public var photos: [PhotoID: Photo] = [:]
  /// The highest `seq` applied, so the next event's is one more.
  public var lastSeq: Int = 0

  public init() {}

  /// A place's path as a collector types it, outermost first: "Office › Shelf 2".
  public func placePath(of id: PlaceID) -> String? {
    var names: [String] = []
    var next: PlaceID? = id
    while let current = next, let place = places[current], names.count < 32 {
      names.insert(place.name, at: 0)
      next = place.parentID
    }
    return names.isEmpty ? nil : names.joined(separator: " \(PlacePath.separator) ")
  }

  /// The places a collector sees: every place not merged into another.
  public var livePlaces: [Place] { places.values.filter { $0.mergedInto == nil } }

  /// Pairs of live places that are probably the same place typed twice, under the same parent (story 109). The app
  /// offers the merge; it never merges alone (PD-151).
  public func nearDuplicatePlaces() -> [(Place, Place)] {
    let live = livePlaces.sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
    var pairs: [(Place, Place)] = []
    for (index, a) in live.enumerated() {
      for b in live[(index + 1)...] where a.parentID == b.parentID && PlacePath.isNearDuplicate(a.name, b.name) {
        pairs.append((a, b))
      }
    }
    return pairs
  }

  /// An object's photos, hero first.
  public func photos(of object: ObjectID) -> [Photo] {
    photos.values.filter { $0.objectID == object }.sorted { ($0.position, $0.id) < ($1.position, $1.id) }
  }

  /// The open loan on an object, if it's lent out or borrowed in.
  public func openLoan(on object: ObjectID) -> Loan? {
    loans.values.first { $0.objectID == object && $0.isOpen }
  }
}

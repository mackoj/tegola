public import Foundation
public import TegolaCatalogue

/// One identity a lookup proposes, in the model's terms: `TegolaClients` maps the contract's `Candidate` to it, so no
/// screen sees a generated type (PLAN §7). Everything in it is a proposal the collector can refuse (PD-042).
public struct LookupCandidate: Hashable, Sendable, Codable {
  /// Why it was proposed, which the review queue says (PD-150). The contract's `Reason.kind`.
  public enum Reason: String, Hashable, Sendable, Codable, CaseIterable {
    case barcode, catalogueNumber, title, ocr, region, subtype, typoCorrected, bundleSplit
  }

  /// Where its data came from, with the words a source requires next to it.
  public struct Source: Hashable, Sendable, Codable {
    public var name: String
    public var attribution: String?

    public init(name: String, attribution: String? = nil) {
      self.name = name
      self.attribution = attribution
    }
  }

  /// How sure the server is, in the bands the review queue shows. Only a strong match is in **Confirm all**.
  public enum Strength: Int, Hashable, Sendable, Comparable {
    case weak, likely, strong

    public static func < (lhs: Strength, rhs: Strength) -> Bool { lhs.rawValue < rhs.rawValue }
  }

  public var releaseID: String
  public var type: TypeManifest.ID
  public var subtype: String?
  /// The spine and the type's fields, as the object would hold them.
  public var values: [FieldKey: FieldValue]
  /// 0 to 1.
  public var confidence: Double
  public var reasons: [Reason]
  public var sources: [Source]

  public init(
    releaseID: String,
    type: TypeManifest.ID,
    subtype: String? = nil,
    values: [FieldKey: FieldValue],
    confidence: Double,
    reasons: [Reason],
    sources: [Source]
  ) {
    self.releaseID = releaseID
    self.type = type
    self.subtype = subtype
    self.values = values
    self.confidence = confidence
    self.reasons = reasons
    self.sources = sources
  }

  /// A match strong enough for **Confirm all** (F8): 0.9 and up. Likely from 0.6. The server's scale is its own; these
  /// cut-offs are where its recorded answers fall (D-69).
  public static let strongFrom = 0.9
  public static let likelyFrom = 0.6

  public var strength: Strength {
    confidence >= Self.strongFrom ? .strong : confidence >= Self.likelyFrom ? .likely : .weak
  }
}

/// What a candidate would fill on an object, before the collector says yes: exactly what `applyLookup` would write,
/// so only empty keys and keys a lookup filled before, never one the collector typed or cleared, never `acquired`,
/// money or a grade (PD-045, promise 1). Empty when it has nothing to add.
public struct EnrichmentProposal: Hashable, Sendable {
  public let objectID: ObjectID
  public let candidate: LookupCandidate
  public let changes: [FieldKey: FieldValue]

  public init(object: ObjectID, candidate: LookupCandidate, shelf: Shelf, catalogue: Catalogue) {
    self.objectID = object
    self.candidate = candidate
    // Only the keys the object's own type has: a field another subtype adds isn't this object's to fill.
    let type = shelf.objects[object].flatMap { try? catalogue.resolve($0.typeID, subtype: $0.subtype) }
    let values = candidate.values.filter { key, _ in
      guard case .field(let name) = key else { return !Self.isAxis(key) }
      return type?.field(name).map { $0.field.kind != .scale } ?? false
    }
    let context = PlanContext(at: .distantPast, source: .lookup, catalogue: catalogue) { Self.anyID }
    let sameType = shelf.objects[object]?.typeID == candidate.type
    let events = sameType ? (try? plan(.applyLookup(object, values: values), on: shelf, context: context)) ?? [] : []
    var changes: [FieldKey: FieldValue] = [:]
    for event in events {
      if case .enriched(_, let filled) = event.kind { changes.merge(filled) { _, new in new } }
    }
    self.changes = changes
  }

  /// A candidate of another type or subtype isn't enrichment: it says the object is something else, which is the
  /// collector's to change (F7).
  public var fits: Bool { !changes.isEmpty }

  /// What the collector accepted, as a command from the lookup: the keys they kept, AUTO until touched (F8).
  public func apply(_ keys: Set<FieldKey>? = nil) -> ShelfCommand {
    .applyLookup(objectID, values: keys.map { keys in changes.filter { keys.contains($0.key) } } ?? changes)
  }

  static func isAxis(_ key: FieldKey) -> Bool { if case .axis = key { true } else { false } }

  static let anyID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

/// What waits for a network: identifiers captured with an object, saved before anything is sent, and drained oldest
/// first when the phone is online (PLAN §7, PD-046). Pure: the worker in `TegolaClients` asks it what's next and
/// tells it what happened.
public struct LookupQueue: Hashable, Sendable, Codable {
  public struct Request: Hashable, Sendable, Codable, Identifiable {
    public enum Identifier: Hashable, Sendable, Codable {
      case barcode(String)
      case catalogueNumber(String)
      /// OCR or typed text, for `POST /types/{type}/search`.
      case text(String)
    }

    public enum State: String, Hashable, Sendable, Codable {
      case waiting
      case answered
      /// Five attempts failed: the object needs details from the collector.
      case needsDetails
    }

    public let id: UUID
    public let objectID: ObjectID
    public let type: TypeManifest.ID
    public let subtype: String?
    public let identifier: Identifier
    public let queuedAt: Date
    public var attempts: Int
    public var lastTriedAt: Date?
    /// Not before this: the backoff, or what the server's `Retry-After` asked for.
    public var notBefore: Date?
    public var state: State

    public init(
      id: UUID,
      objectID: ObjectID,
      type: TypeManifest.ID,
      subtype: String?,
      identifier: Identifier,
      queuedAt: Date
    ) {
      self.id = id
      self.objectID = objectID
      self.type = type
      self.subtype = subtype
      self.identifier = identifier
      self.queuedAt = queuedAt
      self.attempts = 0
      self.state = .waiting
    }
  }

  /// How a try ended.
  public enum Outcome: Hashable, Sendable {
    /// The server answered, with candidates or with none: either way the request is done.
    case answered
    /// The network or the server failed: one attempt spent, then the backoff.
    case failed
    /// `429` or `503`: the server asked to wait. No attempt is spent (PLAN §7: handed back, never slept on).
    case retryAfter(TimeInterval)
  }

  /// Five attempts, then needs details (PLAN §7).
  public static let maxAttempts = 5
  /// The first wait after a failure, doubled each time: 30 s, 1 min, 2 min, 4 min.
  public static let backoff: TimeInterval = 30

  public private(set) var requests: [Request]

  public init(requests: [Request] = []) {
    self.requests = requests
  }

  public mutating func enqueue(_ request: Request) {
    guard !requests.contains(where: { $0.id == request.id }) else { return }
    requests.append(request)
  }

  /// The oldest waiting request whose wait is over.
  public func next(at now: Date) -> Request? {
    requests.filter { $0.state == .waiting && ($0.notBefore.map { $0 <= now } ?? true) }
      .min { ($0.queuedAt, $0.id.uuidString) < ($1.queuedAt, $1.id.uuidString) }
  }

  /// When the next waiting request will be ready, for the worker to sleep until; nil when nothing waits.
  public func nextReady(after now: Date) -> Date? {
    requests.filter { $0.state == .waiting }.map { max($0.notBefore ?? now, now) }.min()
  }

  public mutating func record(_ id: UUID, _ outcome: Outcome, at now: Date) {
    guard let index = requests.firstIndex(where: { $0.id == id }), requests[index].state == .waiting else { return }
    var request = requests[index]
    switch outcome {
    case .answered:
      request.state = .answered
      request.lastTriedAt = now
    case .failed:
      request.attempts += 1
      request.lastTriedAt = now
      if request.attempts >= Self.maxAttempts {
        request.state = .needsDetails
      } else {
        request.notBefore = now + Self.backoff * pow(2, Double(request.attempts - 1))
      }
    case .retryAfter(let seconds):
      request.notBefore = now + max(seconds, 0)
    }
    requests[index] = request
  }

  /// The objects whose lookups gave up: the review queue shows them as needing details.
  public var gaveUp: [ObjectID] { requests.filter { $0.state == .needsDetails }.map(\.objectID) }
}

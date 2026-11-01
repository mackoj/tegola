public import Foundation
public import TegolaCatalogue

/// The review queue (F8, T6.11): every object still to confirm, with what its lookups proposed and why. Pure: the
/// shelf and the queue in, the rows out, so the screen and its tests agree.
public struct ReviewQueue: Hashable, Sendable {
  public struct Row: Hashable, Sendable, Identifiable {
    public var id: ObjectID { object.id }
    public let object: ShelfObject
    /// The answers, most confident first. Empty when nothing was proposed.
    public let candidates: [LookupCandidate]
    /// What confirming the first candidate fills: only empty keys, never the collector's (PD-045).
    public let proposal: EnrichmentProposal?
    /// What the shelf already has that looks like it: "you already own this" (F7), the object itself left out.
    public let lookAlikes: LookAlikes?

    /// A strong match that fills something: the only rows **Confirm all** takes (F8).
    public var isStrong: Bool { (candidates.first?.strength == .strong) && (proposal?.fits ?? false) }
    /// Two or more answers: the collector picks ("Which Tetris?").
    public var asks: Bool { candidates.count > 1 && !isStrong }
  }

  public enum Group: Hashable, Sendable, CaseIterable {
    /// Confirm all takes these.
    case strong
    /// One or more answers, not sure enough.
    case maybe
    /// Nothing proposed: as written, or needing details.
    case asWritten
  }

  public let rows: [Row]

  public init(shelf: Shelf, queue: LookupQueue, catalogue: Catalogue) {
    var answers: [ObjectID: [LookupCandidate]] = [:]
    for request in queue.requests where request.state == .answered {
      answers[request.objectID, default: []] += request.answer ?? []
    }
    rows = shelf.objects.values
      .filter { $0.letGo == nil && ($0.identity == .unconfirmed || $0.identity == .needsDetails) }
      .sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
      .map { object in
        var seen: Set<String> = []
        let candidates = (answers[object.id] ?? [])
          .sorted { $0.confidence > $1.confidence }
          .filter { seen.insert($0.releaseID).inserted }
        let proposal = candidates.first.map {
          EnrichmentProposal(object: object.id, candidate: $0, shelf: shelf, catalogue: catalogue)
        }
        var others = shelf
        others.objects[object.id] = nil
        let lookAlikes = candidates.first.map { candidate in
          LookAlikes(
            ObjectDraft(type: candidate.type, subtype: candidate.subtype, values: candidate.values),
            shelf: others,
            catalogue: catalogue
          )
        }
        return Row(object: object, candidates: candidates, proposal: proposal, lookAlikes: lookAlikes)
      }
  }

  public func rows(in group: Group) -> [Row] {
    rows.filter { row in
      switch group {
      case .strong: row.isStrong
      case .maybe: !row.isStrong && !row.candidates.isEmpty
      case .asWritten: row.candidates.isEmpty
      }
    }
  }

  /// **Confirm all**: the strong matches, each filled from its candidate and confirmed (F8). Never the others.
  public var confirmAll: [ShelfCommand] {
    rows(in: .strong).flatMap { row in [row.proposal!.apply(), .confirm([row.id])] }
  }
}

import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

@Suite struct EnrichmentTests {
  static func candidate(
    _ values: [FieldKey: FieldValue],
    type: TypeManifest.ID = "video-game",
    confidence: Double = 0.95
  )
    -> LookupCandidate
  {
    LookupCandidate(
      releaseID: "r1",
      type: type,
      values: values,
      confidence: confidence,
      reasons: [.title],
      sources: [LookupCandidate.Source(name: "IGDB", attribution: "Data from IGDB")]
    )
  }

  @Test func fillsOnlyEmptyFieldsAfterAsking() throws {
    var harness = Harness()
    let id = try harness.add(values: [.subtitle: .text("Saturn"), .notes: .text("mine")], origin: .imported)
    let offered = Self.candidate([
      .title: .text("Radiant Silvergun (JP)"), .subtitle: .text("Sega Saturn"), .year: .year(1998),
      .field("publisher"): .text("Treasure"), .acquired: .date(Harness.start), .condition: .text("Mint"),
      .axis("boxCondition"): .text("Mint"), .field("spineCard"): .flag(true),
    ])
    let proposal = EnrichmentProposal(
      object: id,
      candidate: offered,
      shelf: harness.shelf,
      catalogue: Harness.catalogue
    )
    // The collector's title and platform stay; the app never writes acquired, a grade, or another subtype's field.
    #expect(proposal.changes == [.year: .year(1998), .field("publisher"): .text("Treasure")])
    // Asking writes nothing; applying the keys the collector kept does, AUTO until touched.
    let before = harness.shelf
    #expect(harness.shelf == before)
    try harness.perform(proposal.apply([.field("publisher")]), as: .lookup)
    let object = try #require(harness.shelf.objects[id])
    #expect(object.values[.field("publisher")] == .text("Treasure") && object.values[.year] == nil)
    #expect(object.auto == [.field("publisher")])
  }

  @Test func anotherTypeIsntEnrichment() throws {
    var harness = Harness()
    let id = try harness.add(origin: .imported)
    let music = Self.candidate([.year: .year(1998)], type: "music")
    #expect(!EnrichmentProposal(object: id, candidate: music, shelf: harness.shelf, catalogue: Harness.catalogue).fits)
  }

  @Test(arguments: [(0.95, LookupCandidate.Strength.strong), (0.9, .strong), (0.7, .likely), (0.2, .weak)])
  func strength(_ confidence: Double, _ strength: LookupCandidate.Strength) {
    #expect(Self.candidate([:], confidence: confidence).strength == strength)
  }
}

@Suite struct LookupQueueTests {
  static let start = Date(timeIntervalSince1970: 1_800_000_000)

  static func request(_ n: Int, at offset: TimeInterval = 0) -> LookupQueue.Request {
    LookupQueue.Request(
      id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!,
      objectID: ObjectID(UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", n))!),
      type: "video-game",
      subtype: "n64",
      identifier: .barcode("045496870010"),
      queuedAt: start + offset
    )
  }

  @Test func drainsOldestFirst() {
    var queue = LookupQueue()
    queue.enqueue(Self.request(2, at: 10))
    queue.enqueue(Self.request(1, at: 0))
    queue.enqueue(Self.request(1, at: 0))
    #expect(queue.requests.count == 2)
    #expect(queue.next(at: Self.start + 20)?.id == Self.request(1).id)
    queue.record(Self.request(1).id, .answered([]), at: Self.start + 20)
    #expect(queue.next(at: Self.start + 20)?.id == Self.request(2).id)
  }

  @Test func backsOffThenGivesUpAfterFiveAttempts() {
    var queue = LookupQueue()
    let id = Self.request(1).id
    queue.enqueue(Self.request(1))
    var now = Self.start
    for (attempt, wait) in [30.0, 60, 120, 240].enumerated() {
      queue.record(id, .failed, at: now)
      #expect(queue.requests[0].attempts == attempt + 1)
      #expect(queue.next(at: now + wait - 1) == nil)
      #expect(queue.nextReady(after: now) == now + wait)
      now += wait
      #expect(queue.next(at: now)?.id == id)
    }
    queue.record(id, .failed, at: now)
    #expect(queue.requests[0].state == .needsDetails)
    #expect(queue.next(at: now + 3600) == nil && queue.nextReady(after: now) == nil)
    #expect(queue.gaveUp == [Self.request(1).objectID])
  }

  @Test func retryAfterWaitsWithoutSpendingAnAttempt() {
    var queue = LookupQueue()
    let id = Self.request(1).id
    queue.enqueue(Self.request(1))
    queue.record(id, .retryAfter(120), at: Self.start)
    #expect(queue.requests[0].attempts == 0)
    #expect(queue.next(at: Self.start + 119) == nil)
    #expect(queue.next(at: Self.start + 120)?.id == id)
    // A finished request doesn't change again.
    queue.record(id, .answered([]), at: Self.start + 120)
    queue.record(id, .failed, at: Self.start + 121)
    #expect(queue.requests[0].state == .answered && queue.requests[0].attempts == 0)
  }
}

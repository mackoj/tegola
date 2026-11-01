public import Dependencies
import DependenciesMacros
public import Foundation
import SQLiteData
import TegolaCatalogue
public import TegolaModel
public import TegolaStorage

#if canImport(Network)
  import Network
#endif

/// The lookup queue's rows (PLAN §7): read what waits, record what happened. Not a shelf change, so not a command: a
/// lookup's answer writes nothing on the shelf until the collector applies it (PD-045, D-69).
@DependencyClient
public struct LookupQueueClient: Sendable {
  public var load: @Sendable () throws -> LookupQueue
  public var record: @Sendable (_ id: UUID, _ outcome: LookupQueue.Outcome, _ at: Date) throws -> Void
  /// Keeps an answer that came without a queued request (Identify's, D-73).
  public var answer: @Sendable (_ object: ObjectID, _ candidates: [LookupCandidate], _ at: Date) throws -> Void
}

extension LookupQueueClient: DependencyKey {
  public static var liveValue: LookupQueueClient {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.catalogue) var catalogue
    return .store(ShelfStore(migrated: database, catalogue: catalogue))
  }

  public static let testValue = LookupQueueClient()

  public static func store(_ store: ShelfStore) -> LookupQueueClient {
    LookupQueueClient(
      load: { try store.lookupQueue() },
      record: { id, outcome, at in try store.recordLookup(id, outcome, at: at) },
      answer: { object, candidates, at in
        @Dependency(\.uuid) var uuid
        try store.recordAnswer(for: object, candidates, at: at, id: uuid())
      }
    )
  }
}

extension DependencyValues {
  public var lookupQueue: LookupQueueClient {
    get { self[LookupQueueClient.self] }
    set { self[LookupQueueClient.self] = newValue }
  }
}

/// Whether the phone can reach the network: the worker waits for it rather than spending attempts offline.
@DependencyClient
public struct ReachabilityClient: Sendable {
  /// The current state, then each change.
  public var updates: @Sendable () -> AsyncStream<Bool> = { AsyncStream { $0.finish() } }
}

extension ReachabilityClient: DependencyKey {
  public static var liveValue: ReachabilityClient {
    #if canImport(Network)
      ReachabilityClient(updates: {
        AsyncStream { continuation in
          let monitor = NWPathMonitor()
          monitor.pathUpdateHandler = { path in continuation.yield(path.status == .satisfied) }
          continuation.onTermination = { _ in monitor.cancel() }
          monitor.start(queue: DispatchQueue(label: "fr.macko.tegola.reachability"))
        }
      })
    #else
      ReachabilityClient(updates: { AsyncStream { $0.yield(true) } })
    #endif
  }

  public static let testValue = ReachabilityClient()
}

extension DependencyValues {
  public var reachability: ReachabilityClient {
    get { self[ReachabilityClient.self] }
    set { self[ReachabilityClient.self] = newValue }
  }
}

/// Drains the lookup queue (PLAN §7, D-73): every request that's ready, oldest first, each tried once per pass. An
/// answer is kept with its request for the review queue; `429`/`503` stops the pass and waits, without spending an
/// attempt; any other failure spends one. Returns when the next request will be ready, for the caller to sleep until.
public enum LookupWorker {
  public static func drain() async throws -> Date? {
    @Dependency(\.lookupQueue) var queue
    @Dependency(\.lookup) var lookup
    @Dependency(\.date) var date
    var tried: Set<UUID> = []
    while let request = try queue.load().next(at: date.now), !tried.contains(request.id) {
      tried.insert(request.id)
      do {
        let candidates = try await lookup.answer(request)
        try queue.record(request.id, .answered(candidates), date.now)
      } catch let LookupFailure.retryAfter(seconds) {
        try queue.record(request.id, .retryAfter(seconds), date.now)
        break
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        try queue.record(request.id, .failed, date.now)
      }
    }
    return try queue.load().nextReady(after: date.now)
  }

  /// Drains, then sleeps until the next request is ready and drains again, while there's one to wait for.
  public static func run() async throws {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.date) var date
    while let next = try await drain() {
      let wait = max(next.timeIntervalSince(date.now), 1)
      try await clock.sleep(for: .seconds(min(wait, 15 * 60)))
    }
  }
}

public import Dependencies
import DependenciesMacros
import Foundation
import SQLiteData
import TegolaCatalogue
public import TegolaModel
public import TegolaStorage

/// Every change to the shelf goes through here: a `ShelfCommand` in, a receipt out (PLAN §3.1). Features read the
/// shelf through queries; they write only through `perform`.
@DependencyClient
public struct ShelfClient: Sendable {
  /// Checks the command against the rules, appends its events and updates the projection, in one transaction. Throws
  /// `ShelfRuleViolation` for a command the rules refuse, and writes nothing.
  public var perform: @Sendable (_ command: ShelfCommand, _ source: ShelfEvent.Source) throws -> CommandReceipt
  /// A capture's add, with what the camera read queued for a lookup in the same transaction, so the object is saved
  /// before any network (PLAN §7, PD-046).
  public var capture:
    @Sendable (_ command: ShelfCommand, _ lookup: LookupQueue.Request.Identifier?) throws -> CommandReceipt
}

extension ShelfClient {
  /// The collector's own command: what every screen sends.
  public func perform(_ command: ShelfCommand) throws -> CommandReceipt {
    try perform(command, .collector)
  }

  /// A client over a store: the time from `date`, new ids from `uuid`.
  public static func store(_ store: ShelfStore) -> ShelfClient {
    @Sendable func context(_ source: ShelfEvent.Source) -> PlanContext {
      @Dependency(\.date.now) var now
      @Dependency(\.uuid) var uuid
      @Dependency(\.calendar) var calendar
      return PlanContext(at: now, source: source, catalogue: store.catalogue, calendar: calendar, makeID: { uuid() })
    }
    return ShelfClient(
      perform: { command, source in try store.perform(command, context: context(source)) },
      capture: { command, lookup in try store.perform(command, context: context(.capture), lookup: lookup) }
    )
  }
}

extension ShelfClient: DependencyKey {
  /// The app's database, as `bootstrapDatabase` opened it.
  public static var liveValue: ShelfClient {
    @Dependency(\.defaultDatabase) var database
    do {
      return .store(ShelfStore(migrated: database, catalogue: try Catalogue.bundled()))
    } catch {
      reportIssue(error)
      return Self()
    }
  }

  /// Unimplemented: a test says which commands it expects.
  public static let testValue = ShelfClient()
}

extension DependencyValues {
  public var shelf: ShelfClient {
    get { self[ShelfClient.self] }
    set { self[ShelfClient.self] = newValue }
  }
}

public import Foundation
public import TegolaCatalogue

/// The first piece's payoff (46, screen 03): within twenty seconds, the piece already tells its collector something
/// they didn't know. That's what its clocks say now, or, when they have nothing to say yet, when they will.
public struct FirstPiecePayoff: Hashable, Sendable {
  public enum Line: Hashable, Sendable {
    /// "Your save is at risk": a clock needs attention now.
    case now(Signal)
    /// "Not yet. Soon. We'll tell you when it's time": every clock reads good, and the soonest turns watch then.
    case later(clock: String, from: Date)
  }

  /// Nil for a piece with no clock, or none with a basis to estimate from: the payoff is then its story alone.
  public let line: Line?

  public init(object: ShelfObject, type: EffectiveType, now: Date, calendar: Calendar) {
    let readings = signals(for: object, type: type, now: now, calendar: calendar)
    // `min` keeps the type's order between equally urgent clocks.
    if let urgent = readings.filter(\.status.needsAttention).min(by: { $0.status < $1.status }) {
      line = .now(urgent)
      return
    }
    let upcoming = readings.compactMap { signal in signal.changesAt.map { (clock: signal.clock, from: $0) } }
    line = upcoming.min { $0.from < $1.from }.map { .later(clock: $0.clock, from: $0.from) }
  }
}

extension Shelf {
  /// The pieces saved as Things while they wait for `type` to ship (D-63): the ones offered its migration first
  /// (PD-031). Let-go pieces don't wait.
  public func waiting(for type: TypeManifest.ID) -> [ShelfObject] {
    objects.values
      .filter { $0.awaitingType == type && $0.letGo == nil }
      .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
  }
}

/// The types a collector said **Count me in** to (46, 2B; PD-031), as the setting stores them: ids, sorted, joined by
/// commas, so the row reads the same however they were added.
public struct TypeTesters: Hashable, Sendable {
  public private(set) var types: Set<TypeManifest.ID>

  public init(_ types: Set<TypeManifest.ID> = []) { self.types = types }

  public init(setting: String?) {
    let ids = (setting ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    types = Set(ids.filter { !$0.isEmpty }.map { TypeManifest.ID(rawValue: $0) })
  }

  public var setting: String { types.map(\.rawValue).sorted().joined(separator: ",") }

  public func contains(_ type: TypeManifest.ID) -> Bool { types.contains(type) }

  public func adding(_ type: TypeManifest.ID) -> TypeTesters { TypeTesters(types.union([type])) }
}

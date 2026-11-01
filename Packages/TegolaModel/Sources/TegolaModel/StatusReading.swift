public import Foundation
public import TegolaCatalogue

/// The one chip an object carries (PD-016): a swatch, and why. Derived here, never in a view (D-15).
public struct StatusReading: Hashable, Sendable {
  public enum Reason: Hashable, Sendable {
    /// Let go, into the archive.
    case letGo
    /// Lent out past its due date.
    case overdue(LoanID)
    /// A clock says something: watch, act, or the good moment ("Drink it"). Always an estimate.
    case clock(ClockSignal)
    /// Saved from a photo with nothing identified.
    case needsDetails
    /// A guess the collector hasn't agreed to yet.
    case unconfirmed
    /// Lent out, not yet due back: "Out".
    case lent(LoanID)
    /// Nothing to say.
    case settled
  }

  public let status: ObjectStatus
  public let reason: Reason

  /// Whether this counts in "need attention", the one number that crosses types (PD-016). Only signals do: a clock or
  /// an overdue loan. A to-tidy object is counted by the Today strip's own line, never twice.
  public var isSignal: Bool {
    switch reason {
    case .overdue: status.needsAttention
    case .clock(let signal): signal.status.needsAttention
    case .letGo, .needsDetails, .unconfirmed, .lent, .settled: false
    }
  }

  /// The reading for one object now. `type` is the object's resolved type; without one (a type the catalogue no
  /// longer has), no clock runs.
  public static func derive(
    for object: ShelfObject,
    type: EffectiveType?,
    shelf: Shelf,
    now: Date,
    calendar: Calendar
  ) -> StatusReading {
    if object.letGo != nil { return StatusReading(status: .gone, reason: .letGo) }
    // Candidates in order of precedence; the most urgent status wins, and between equals the earlier one does.
    var candidates: [StatusReading] = []
    let loan = shelf.loans.values
      .filter { $0.objectID == object.id && $0.isOpen && $0.direction == .out }
      .min { $0.openedAt < $1.openedAt }
    if let loan, let due = loan.dueAt, due < now {
      candidates.append(StatusReading(status: .act, reason: .overdue(loan.id)))
    }
    // Clocks are about the collector's own things: a wanted or a borrowed object's care isn't theirs.
    if object.ownership == .owned, let type {
      for signal in Clocks.signals(for: object, type: type, now: now, calendar: calendar)
      where !object.isDismissed(signal) {
        candidates.append(StatusReading(status: signal.status, reason: .clock(signal)))
      }
    }
    switch object.identity {
    case .needsDetails: candidates.append(StatusReading(status: .watch, reason: .needsDetails))
    case .unconfirmed: candidates.append(StatusReading(status: .watch, reason: .unconfirmed))
    case .confirmed: break
    }
    if let loan { candidates.append(StatusReading(status: .fine, reason: .lent(loan.id))) }
    candidates.append(StatusReading(status: .fine, reason: .settled))
    return candidates.enumerated().min { ($0.element.status, $0.offset) < ($1.element.status, $1.offset) }!.element
  }

  /// Every object's reading, resolving each type and subtype once.
  public static func all(
    shelf: Shelf,
    catalogue: Catalogue,
    now: Date,
    calendar: Calendar
  ) -> [ObjectID: StatusReading] {
    var types: [String: EffectiveType?] = [:]
    var readings: [ObjectID: StatusReading] = [:]
    for object in shelf.objects.values {
      let key = "\(object.typeID.rawValue)/\(object.subtype ?? "")"
      if types[key] == nil { types[key] = try? catalogue.resolve(object.typeID, subtype: object.subtype) }
      readings[object.id] = derive(for: object, type: types[key] ?? nil, shelf: shelf, now: now, calendar: calendar)
    }
    return readings
  }
}

extension ShelfObject {
  /// A dismissed clock stays hidden until it becomes more urgent than when it was dismissed (T4.3).
  public func isDismissed(_ signal: ClockSignal) -> Bool {
    guard let hidden = dismissed?[signal.clock] else { return false }
    return !(signal.status < hidden)
  }
}

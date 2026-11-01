public import Foundation
public import TegolaCatalogue

extension ObjectStatus {
  /// The one chip an object carries (D-15, D-59). Let go is *gone*. Only what's owned has signals: wanted and borrowed
  /// objects aren't the collector's to look after, so they're *fine*. Otherwise the most urgent of its showing signals,
  /// raised to *act* by a loan out past its due date; *fine* when nothing speaks.
  public static func derive(object: ShelfObject, signals: [Signal], openLoan: Loan?, now: Date) -> ObjectStatus {
    if object.letGo != nil { return .gone }
    guard object.ownership == .owned else { return .fine }
    var status = signals.map(\.status).min() ?? .fine
    if let loan = openLoan, loan.isOverdue(at: now) { status = .act }
    return status
  }
}

extension Loan {
  /// Out to someone and past its due date.
  public func isOverdue(at now: Date) -> Bool {
    isOpen && direction == .out && (dueAt.map { $0 < now } ?? false)
  }
}

/// The whole shelf's signals and statuses at a moment: what the Today strip, the signal feed, the status filters and
/// the object's status slot read (F15). Pure, like every read model.
public struct ShelfSignals: Hashable, Sendable {
  /// The signals showing on each object that has any, in its type's clock order.
  public let signals: [ObjectID: [Signal]]
  /// Every object's status.
  public let statuses: [ObjectID: ObjectStatus]

  public init(shelf: Shelf, catalogue: Catalogue, now: Date, calendar: Calendar, optedIn: Set<String> = []) {
    var types: [String: EffectiveType] = [:]
    var signals: [ObjectID: [Signal]] = [:]
    var statuses: [ObjectID: ObjectStatus] = [:]
    let loans = Dictionary(
      shelf.loans.values.filter(\.isOpen).map { ($0.objectID, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    for object in shelf.objects.values {
      var showing: [Signal] = []
      if object.ownership == .owned && object.letGo == nil {
        let key = "\(object.typeID.rawValue)/\(object.subtype ?? "")"
        if types[key] == nil { types[key] = try? catalogue.resolve(object.typeID, subtype: object.subtype) }
        if let type = types[key] {
          showing = TegolaModel.signals(for: object, type: type, now: now, calendar: calendar, optedIn: optedIn)
        }
      }
      if !showing.isEmpty { signals[object.id] = showing }
      statuses[object.id] = ObjectStatus.derive(
        object: object,
        signals: showing,
        openLoan: loans[object.id],
        now: now
      )
    }
    self.signals = signals
    self.statuses = statuses
  }

  /// The objects with a signal that needs attention: what the Today strip's line counts.
  public var signalled: Set<ObjectID> {
    Set(signals.filter { $0.value.contains(where: \.status.needsAttention) }.keys)
  }

  /// The signal feed: every signal that needs attention, most urgent first, then soonest to change.
  public var feed: [(object: ObjectID, signal: Signal)] {
    signals.flatMap { id, list in list.filter(\.status.needsAttention).map { (object: id, signal: $0) } }
      .sorted {
        ($0.signal.status, $0.signal.changesAt ?? .distantFuture, $0.object)
          < ($1.signal.status, $1.signal.changesAt ?? .distantFuture, $1.object)
      }
  }
}

public import Foundation
public import TegolaCatalogue

/// A clock's reading on one object (F15, page 52 P2): a status, the reason behind it, and when it next changes. It's
/// computed, never typed, so it's always an **Estimate**. The status it gives is one of good, watch or act; the
/// object's chip is derived from its signals and its other states (D-15).
public struct Signal: Hashable, Sendable {
  /// The library clock that gave it (`ClockLibrary`).
  public let clock: String
  public let status: ObjectStatus
  public let reason: Reason
  /// When the reading moves to its next status, for a notification. `nil` when it can't get more urgent.
  public let changesAt: Date?

  /// Every signal is an estimate, and every screen labels it so (One Roof, "the estimate label").
  public var isEstimate: Bool { true }

  public init(clock: String, status: ObjectStatus, reason: Reason, changesAt: Date?) {
    self.clock = clock
    self.status = status
    self.reason = reason
    self.changesAt = changesAt
  }

  /// What the reading rests on, as data. The screen words it ("Battery from 1994, usually lasts 25–35 years").
  public enum Reason: Hashable, Sendable {
    /// A save battery fitted, or last swapped, in a year, and how long one usually lasts.
    case battery(since: Int, swapped: Bool, lastsYears: ClosedRange<Int>)
    /// A download code's expiry date.
    case codeExpires(Date)
    /// A bottle's drinking window, in years.
    case drinkingWindow(ClosedRange<Int>)
    /// The last service, and how often one is due.
    case serviced(last: Date, everyMonths: Int)
    /// Media last checked (or made) in a year, and how often it should be checked.
    case checked(since: Int, wasChecked: Bool, everyYears: Int)
  }
}

extension ShelfEvent.Kind {
  /// The `logged` kind a service writes: "Log a battery swap" is one (F15). It resets the clocks that read it.
  public static let servicedKind = "serviced"
}

/// The signals an object's clocks give at `now`: one per clock the type runs, in the type's order. A clock held back
/// (`-pending`, D-37) gives none, and so does one with nothing to read. Pure: the object's events, the moment and
/// the calendar come in, so the same inputs give the same reading.
public func signals(
  for object: ShelfObject,
  type: EffectiveType,
  events: [ShelfEvent],
  now: Date,
  calendar: Calendar
) -> [Signal] {
  let reading = ClockReading(object: object, events: events, now: now, calendar: calendar)
  return type.clocks.compactMap { reference in
    guard !reference.isPending, let definition = reference.definition else { return nil }
    return reading.signal(definition)
  }
}

/// What every clock reads from one object, computed once.
struct ClockReading {
  let values: [FieldKey: FieldValue]
  let now: Date
  let calendar: Calendar
  /// The latest `serviced` event on the object.
  let lastServiced: Date?

  init(values: [FieldKey: FieldValue], lastServiced: Date?, now: Date, calendar: Calendar) {
    self.values = values
    self.lastServiced = lastServiced
    self.now = now
    self.calendar = calendar
  }

  init(object: ShelfObject, events: [ShelfEvent], now: Date, calendar: Calendar) {
    let lastServiced =
      events
      .filter { event in
        guard event.at <= now, case .logged(let id, let kind, _) = event.kind else { return false }
        return id == object.id && kind == ShelfEvent.Kind.servicedKind
      }
      .map(\.at).max()
    self.init(values: object.values, lastServiced: lastServiced, now: now, calendar: calendar)
  }

  func signal(_ clock: ClockDefinition) -> Signal? {
    let parameter = { (name: String) in clock.parameters[name].map { Int($0) } ?? 0 }
    switch clock.name {
    case "saveBattery":
      return saveBattery(clock.name, from: parameter("lifespanFromYears"), to: parameter("lifespanToYears"))
    case "codeExpiry":
      return codeExpiry(clock.name, warnDays: parameter("warnDaysBefore"))
    case "drinkingWindow":
      return drinkingWindow(clock.name, warnYears: parameter("warnYearsBefore"))
    case "serviceRisk":
      return serviceRisk(clock.name, everyMonths: parameter("intervalMonths"))
    case "mediaRot", "discRot":
      return check(clock.name, everyYears: parameter("checkEveryYears"))
    default:
      return nil
    }
  }

  // MARK: The clocks

  /// The battery's age from its swap, the date it was fitted, or else the release year: good while young, watch
  /// from the low end of its lifespan, act from the high end.
  func saveBattery(_ name: String, from: Int, to: Int) -> Signal? {
    let fitted: Date? = if case .date(let date) = values[.field("saveBattery")] { date } else { nil }
    let released: Date? = if case .year(let year) = values[.year] { startOf(year) } else { nil }
    let swapped = lastServiced.map { swap in fitted.map { swap >= $0 } ?? true } ?? false
    guard let since = swapped ? lastServiced : (fitted ?? released) else { return nil }
    let reason = Signal.Reason.battery(since: year(of: since), swapped: swapped, lastsYears: from...max(from, to))
    return stepped(name, reason, thresholds: [add(.year, from, to: since), add(.year, to, to: since)])
  }

  /// Watch inside the warning window before the code expires, act once it has.
  func codeExpiry(_ name: String, warnDays: Int) -> Signal? {
    guard case .date(let expires) = values[.field("codeExpires")] else { return nil }
    return stepped(name, .codeExpires(expires), thresholds: [add(.day, -warnDays, to: expires), expires])
  }

  /// Good before the window draws near, watch from a year before it opens, act in its last year and after.
  func drinkingWindow(_ name: String, warnYears: Int) -> Signal? {
    guard case .yearRange(let from, let to) = values[.field("drinkingWindow")] else { return nil }
    let window = min(from, to)...max(from, to)
    return stepped(
      name,
      .drinkingWindow(window),
      thresholds: [startOf(window.lowerBound - warnYears), startOf(window.upperBound)]
    )
  }

  /// Watch once the interval has passed since the last service, act at twice it. No known service, no signal.
  func serviceRisk(_ name: String, everyMonths: Int) -> Signal? {
    let field: Date? = if case .date(let date) = values[.field("lastServiced")] { date } else { nil }
    guard let last = [field, lastServiced].compactMap({ $0 }).max(), everyMonths > 0 else { return nil }
    return stepped(
      name,
      .serviced(last: last, everyMonths: everyMonths),
      thresholds: [add(.month, everyMonths, to: last), add(.month, 2 * everyMonths, to: last)]
    )
  }

  /// Media due a check: watch once the interval has passed since the last service, or since it was made.
  func check(_ name: String, everyYears: Int) -> Signal? {
    let made: Date? = if case .year(let year) = values[.year] { startOf(year) } else { nil }
    guard let since = lastServiced ?? made, everyYears > 0 else { return nil }
    let reason = Signal.Reason.checked(since: year(of: since), wasChecked: lastServiced != nil, everyYears: everyYears)
    return stepped(name, reason, thresholds: [add(.year, everyYears, to: since)])
  }

  // MARK: Helpers

  /// good → watch → act at each threshold in turn; the next threshold is when it changes.
  func stepped(_ name: String, _ reason: Signal.Reason, thresholds: [Date]) -> Signal {
    let steps: [ObjectStatus] = [.good, .watch, .act]
    let passed = thresholds.prefix { $0 <= now }.count
    return Signal(
      clock: name,
      status: steps[passed],
      reason: reason,
      changesAt: passed < thresholds.count ? thresholds[passed] : nil
    )
  }

  func startOf(_ year: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .distantPast
  }

  func year(of date: Date) -> Int { calendar.component(.year, from: date) }

  func add(_ component: Calendar.Component, _ amount: Int, to date: Date) -> Date {
    calendar.date(byAdding: component, value: amount, to: date) ?? date
  }
}

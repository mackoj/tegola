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

  /// What the collector can do about it, when there's one thing to do: it resets the clock (F15, D-58).
  public var remedy: Remedy? { Self.remedy(for: clock) }

  /// A clock's remedy, by its name.
  public static func remedy(for clock: String) -> Remedy? {
    switch clock {
    case "saveBattery": .batterySwap
    case "mediaRot", "discRot": .backup
    case "serviceRisk": .service
    default: nil
    }
  }

  public enum Remedy: Hashable, Sendable {
    case batterySwap, backup, service

    /// The `logged` kind it writes.
    public var kind: String {
      switch self {
      case .batterySwap, .service: ShelfEvent.Kind.servicedKind
      case .backup: ShelfEvent.Kind.backedUpKind
      }
    }
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
    /// A game marked as playing since a date, and never finished (D-20).
    case unfinished(since: Date)
  }
}

/// What an object's clocks read beyond its values, kept by `apply` (D-59). Stored on the object, so reading a whole
/// shelf's signals needs no event history.
public struct SignalState: Hashable, Sendable, Codable {
  /// The latest `serviced` event.
  public var lastServiced: Date?
  /// The latest `backedUp` event (D-58).
  public var lastBackedUp: Date?
  /// When `playStatus` last turned to Playing, while it still is.
  public var playingSince: Date?
  /// Dismissed clocks, by name, and the status each read when dismissed (D-60). Empty once what they read changes.
  public var dismissed: [String: ObjectStatus]

  public init(
    lastServiced: Date? = nil,
    lastBackedUp: Date? = nil,
    playingSince: Date? = nil,
    dismissed: [String: ObjectStatus] = [:]
  ) {
    self.lastServiced = lastServiced
    self.lastBackedUp = lastBackedUp
    self.playingSince = playingSince
    self.dismissed = dismissed
  }

  enum CodingKeys: String, CodingKey { case lastServiced, lastBackedUp, playingSince, dismissed }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    lastServiced = try container.decodeIfPresent(Date.self, forKey: .lastServiced)
    lastBackedUp = try container.decodeIfPresent(Date.self, forKey: .lastBackedUp)
    playingSince = try container.decodeIfPresent(Date.self, forKey: .playingSince)
    dismissed = try container.decodeIfPresent([String: ObjectStatus].self, forKey: .dismissed) ?? [:]
  }

  /// A dismissed clock shows again once its reading is more urgent than when it was dismissed.
  func hides(_ signal: Signal) -> Bool {
    guard let status = dismissed[signal.clock] else { return false }
    return !(signal.status < status)
  }

  func with(_ change: (inout Self) -> Void) -> Self {
    var copy = self
    change(&copy)
    return copy
  }
}

/// What a dismissal records (risk R2): the clock, the status it read, and the parameters in force. Shape, never the
/// object's content, so the log can say which clocks people disagree with.
public struct SignalDismissal: Hashable, Sendable, Codable {
  public let clock: String
  public let status: ObjectStatus
  public let parameters: [String: Double]

  public init(clock: String, status: ObjectStatus, parameters: [String: Double]) {
    self.clock = clock
    self.status = status
    self.parameters = parameters
  }

}

extension SignalState? {
  func or() -> SignalState { self ?? SignalState() }
}

extension ShelfObject {
  static let playStatus = FieldKey.field("playStatus")
  static let playing = FieldValue.text("Playing")

  /// The keys the clocks read: a change to any of them is new evidence, so dismissals lapse (D-60).
  static let clockInputs: [FieldKey] = [
    .year, .field("saveBattery"), .field("codeExpires"), .field("drinkingWindow"), .field("lastServiced"), playStatus,
  ]

  /// After a change to its values: dismissals lapse if what the clocks read changed; note when it started Playing,
  /// and forget it once it's anything else.
  mutating func noteValues(before: [FieldKey: FieldValue], at: Date) {
    if let state = signalState, !state.dismissed.isEmpty,
      Self.clockInputs.contains(where: { values[$0] != before[$0] })
    {
      signalState = state.with { $0.dismissed = [:] }
    }
    let now = values[Self.playStatus]
    guard now != before[Self.playStatus] else { return }
    if now == Self.playing {
      signalState = signalState.or().with { $0.playingSince = at }
    } else if signalState?.playingSince != nil {
      signalState = signalState.or().with { $0.playingSince = nil }
    }
  }
}

extension ShelfEvent.Kind {
  /// The `logged` kind a service writes: "Log a battery swap" is one (F15). It resets the clocks that read it.
  public static let servicedKind = "serviced"
  /// The `logged` kind **Make a backup** writes, on media the clocks say is ageing (D-58). It resets them like a check.
  public static let backedUpKind = "backedUp"
}

/// The signals an object's clocks give at `now`: one per clock the type runs, in the type's order. A clock held back
/// (`-pending`, D-37) gives none, and so does one with nothing to read, or an opt-in clock the collector hasn't turned
/// on. Pure: the object (with its `signalState`), the moment and the calendar come in.
public func signals(
  for object: ShelfObject,
  type: EffectiveType,
  now: Date,
  calendar: Calendar,
  optedIn: Set<String> = []
) -> [Signal] {
  let reading = ClockReading(object: object, now: now, calendar: calendar)
  return type.clocks.compactMap { reference in
    guard !reference.isPending, let definition = reference.definition,
      !definition.isOptIn || optedIn.contains(definition.name),
      let signal = reading.signal(definition), object.signalState?.hides(signal) != true
    else { return nil }
    return signal
  }
}

/// What every clock reads from one object, computed once.
struct ClockReading {
  let values: [FieldKey: FieldValue]
  let now: Date
  let calendar: Calendar
  /// The latest `serviced` event on the object.
  let lastServiced: Date?
  /// The latest `backedUp` event: media that's been backed up counts as checked (D-58).
  let lastBackedUp: Date?
  /// When `playStatus` last became Playing, if it still is.
  let playingSince: Date?

  init(
    values: [FieldKey: FieldValue],
    lastServiced: Date?,
    lastBackedUp: Date? = nil,
    playingSince: Date? = nil,
    now: Date,
    calendar: Calendar
  ) {
    self.values = values
    self.lastServiced = lastServiced
    self.lastBackedUp = lastBackedUp
    self.playingSince = playingSince
    self.now = now
    self.calendar = calendar
  }

  init(object: ShelfObject, now: Date, calendar: Calendar) {
    let state = object.signalState ?? SignalState()
    // A moment after `now` hasn't happened yet: reading the past stays the past.
    let past = { (date: Date?) in date.flatMap { $0 <= now ? $0 : nil } }
    self.init(
      values: object.values,
      lastServiced: past(state.lastServiced),
      lastBackedUp: past(state.lastBackedUp),
      playingSince: past(state.playingSince),
      now: now,
      calendar: calendar
    )
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
    case "unfinished":
      return unfinished(clock.name, afterMonths: parameter("afterMonths"))
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

  /// Media due another backup: watch once the interval has passed since the last backup or check, act at twice it
  /// (D-58). It starts at the first one: counting from the year it was made would put every tape on the shelf in the
  /// feed. Until then the object offers **Make a backup** without a signal.
  func check(_ name: String, everyYears: Int) -> Signal? {
    guard let since = [lastServiced, lastBackedUp].compactMap({ $0 }).max(), everyYears > 0 else { return nil }
    let reason = Signal.Reason.checked(since: year(of: since), wasChecked: true, everyYears: everyYears)
    return stepped(
      name,
      reason,
      thresholds: [add(.year, everyYears, to: since), add(.year, 2 * everyYears, to: since)]
    )
  }

  /// Watch once a game has been Playing for the given months: "started 14 months ago, never finished". No act.
  func unfinished(_ name: String, afterMonths: Int) -> Signal? {
    guard let since = playingSince, afterMonths > 0 else { return nil }
    return stepped(name, .unfinished(since: since), thresholds: [add(.month, afterMonths, to: since)])
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

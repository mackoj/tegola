public import Foundation
public import TegolaCatalogue

/// The kinds of care a collector logs (story 54), as `ShelfCommand.logEvent` writes them. The clocks read the latest
/// date of each (`ShelfObject.latestLog`).
public enum CareKind {
  public static let serviced = "serviced"
  public static let cleaned = "cleaned"
  public static let checked = "checked"
  public static let batterySwapped = "batterySwapped"
}

/// What a clock says about one object now. Always an estimate (PD-017): the screen labels it **Estimate**.
public struct ClockSignal: Hashable, Sendable {
  /// Why the clock says what it says, as data, so the screen words it (and translates it) and a test can check it.
  public enum Reason: Hashable, Sendable {
    /// The save battery was fitted in this year and is approaching its usual lifespan.
    case batteryAging(fitted: Int, lifespanYears: Int)
    /// The save battery is past its usual lifespan.
    case batteryPastLifespan(fitted: Int, lifespanYears: Int)
    /// A disc or tape is due a check; `since` is the last check, or the release year when there's none.
    case checkDue(since: Int, everyYears: Int)
    case codeExpiring(on: Date)
    case codeExpired(on: Date)
    case windowOpensSoon(from: Int)
    /// The drinking window is open: the "Drink it" moment (One Roof's example).
    case windowOpen(from: Int, to: Int)
    case windowClosing(to: Int)
    case windowPast(to: Int)
    /// `since` is the last service, or the release year.
    case serviceDue(since: Int, intervalMonths: Int)
    case serviceOverdue(since: Int, intervalMonths: Int)
  }

  public let clock: String
  /// Good, watch or act: a clock with nothing to say gives no signal.
  public let status: ObjectStatus
  public let reason: Reason
  /// When the clock will next say something different, for notifications (T4.6). Nil when nothing changes.
  public let changesAt: Date?
}

/// The library's functions (D-37's catalogue, PLAN §3.3). Each reads an object's fields and its latest logged care,
/// with the parameters `ClockLibrary` holds. Pure: the same object at the same moment always gives the same signal.
public enum Clocks {
  /// The signal one clock gives an object now, or nil when it has nothing to say: no basis to estimate from, too
  /// early, or a clock held pending (D-37, D-56).
  public static func signal(
    _ clock: ClockReference,
    for object: ShelfObject,
    now: Date,
    calendar: Calendar
  ) -> ClockSignal? {
    guard !clock.isPending, let definition = clock.definition else { return nil }
    let parameter = { (name: String) in definition.parameters[name] ?? 0 }
    let context = Context(object: object, now: now, calendar: calendar)
    switch clock.name {
    case "saveBattery":
      return context.saveBattery(lifespan: Int(parameter("lifespanYears")), warn: Int(parameter("warnYearsBefore")))
    case "discRot", "mediaRot":
      return context.checkDue(clock: clock.name, every: Int(parameter("checkEveryYears")))
    case "codeExpiry":
      return context.codeExpiry(warnDays: Int(parameter("warnDaysBefore")))
    case "drinkingWindow":
      return context.drinkingWindow(warn: Int(parameter("warnYearsBefore")))
    case "serviceRisk":
      return context.serviceRisk(intervalMonths: Int(parameter("intervalMonths")))
    default:
      return nil
    }
  }

  /// Every signal an object's clocks give now, most urgent first.
  public static func signals(
    for object: ShelfObject,
    type: EffectiveType,
    now: Date,
    calendar: Calendar
  ) -> [ClockSignal] {
    type.clocks.compactMap { signal($0, for: object, now: now, calendar: calendar) }.sorted { $0.status < $1.status }
  }
}

private struct Context {
  let object: ShelfObject
  let now: Date
  let calendar: Calendar

  func date(_ key: FieldKey) -> Date? {
    if case .date(let date) = object.values[key] { date } else { nil }
  }

  /// The spine year, as the first of January: the oldest the object can be.
  var releaseDate: Date? {
    guard case .year(let year) = object.values[.year] else { return nil }
    return calendar.date(from: DateComponents(year: year, month: 1, day: 1))
  }

  func care(_ kinds: String...) -> Date? {
    kinds.compactMap { object.latestLog?[$0] }.max()
  }

  func year(_ date: Date) -> Int { calendar.component(.year, from: date) }

  func adding(_ component: Calendar.Component, _ value: Int, to date: Date) -> Date {
    calendar.date(byAdding: component, value: value, to: date) ?? date
  }

  /// The battery was fitted when the field says (an owner who replaced it writes the date), or at the last logged
  /// swap, whichever is later; otherwise with the game.
  func saveBattery(lifespan: Int, warn: Int) -> ClockSignal? {
    let fitted = [date(.field("saveBattery")), care(CareKind.batterySwapped)].compactMap { $0 }.max() ?? releaseDate
    guard let fitted else { return nil }
    let dies = adding(.year, lifespan, to: fitted)
    let warns = adding(.year, lifespan - warn, to: fitted)
    if now >= dies {
      return ClockSignal(
        clock: "saveBattery", status: .act,
        reason: .batteryPastLifespan(fitted: year(fitted), lifespanYears: lifespan), changesAt: nil)
    }
    if now >= warns {
      return ClockSignal(
        clock: "saveBattery", status: .watch,
        reason: .batteryAging(fitted: year(fitted), lifespanYears: lifespan), changesAt: dies)
    }
    return nil
  }

  /// Media that should be played or looked at every few years. Only ever watch: disc rot can't be told from folklore
  /// (PD-018), so the clock never claims more than "worth a look".
  func checkDue(clock: String, every years: Int) -> ClockSignal? {
    guard let since = care(CareKind.checked, CareKind.serviced, CareKind.cleaned) ?? releaseDate else { return nil }
    let due = adding(.year, years, to: since)
    guard now >= due else { return nil }
    return ClockSignal(
      clock: clock, status: .watch, reason: .checkDue(since: year(since), everyYears: years), changesAt: nil)
  }

  func codeExpiry(warnDays: Int) -> ClockSignal? {
    guard let expires = date(.field("expires")) else { return nil }
    if now >= expires {
      return ClockSignal(clock: "codeExpiry", status: .act, reason: .codeExpired(on: expires), changesAt: nil)
    }
    let warns = adding(.day, -warnDays, to: expires)
    guard now >= warns else { return nil }
    return ClockSignal(clock: "codeExpiry", status: .watch, reason: .codeExpiring(on: expires), changesAt: expires)
  }

  /// Before the window: watch from `warn` years ahead. In it: good, the moment to open one, until its last `warn`
  /// years, when it's watch. After it: act.
  func drinkingWindow(warn: Int) -> ClockSignal? {
    guard case .yearRange(let from, let to) = object.values[.field("drinkingWindow")] else { return nil }
    let this = year(now)
    let startOf = { (year: Int) in calendar.date(from: DateComponents(year: year, month: 1, day: 1)) }
    switch this {
    case ..<(from - warn):
      return nil
    case ..<from:
      return ClockSignal(
        clock: "drinkingWindow", status: .watch, reason: .windowOpensSoon(from: from), changesAt: startOf(from))
    case ...(to - warn):
      return ClockSignal(
        clock: "drinkingWindow", status: .good, reason: .windowOpen(from: from, to: to),
        changesAt: startOf(to - warn + 1))
    case ...to:
      return ClockSignal(
        clock: "drinkingWindow", status: .watch, reason: .windowClosing(to: to), changesAt: startOf(to + 1))
    default:
      return ClockSignal(clock: "drinkingWindow", status: .act, reason: .windowPast(to: to), changesAt: nil)
    }
  }

  /// Watch once a service interval has passed since the last service (logged, or the field), act at twice that.
  func serviceRisk(intervalMonths: Int) -> ClockSignal? {
    let since = [date(.field("lastServiced")), care(CareKind.serviced)].compactMap { $0 }.max() ?? releaseDate
    guard let since else { return nil }
    let due = adding(.month, intervalMonths, to: since)
    let overdue = adding(.month, intervalMonths * 2, to: since)
    if now >= overdue {
      return ClockSignal(
        clock: "serviceRisk", status: .act,
        reason: .serviceOverdue(since: year(since), intervalMonths: intervalMonths), changesAt: nil)
    }
    guard now >= due else { return nil }
    return ClockSignal(
      clock: "serviceRisk", status: .watch,
      reason: .serviceDue(since: year(since), intervalMonths: intervalMonths), changesAt: overdue)
  }
}

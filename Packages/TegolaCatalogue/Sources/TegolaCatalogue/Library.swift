/// The clocks the app owns (page 52, P2; PLAN §3.3). A type names the ones it uses and can't define its own. Each is a
/// named, parameterised estimate over an object's fields and events, always labelled **Estimate**. This is the
/// library's catalogue: names, what each reads and its parameters. The functions that compute a signal arrive with
/// signals in M4.
public struct ClockDefinition: Hashable, Sendable {
  public let name: String
  /// What the collector reads, in a few words.
  public let summary: String
  /// The field kinds or event kinds the clock reads, for a reviewer checking a type that names it.
  public let reads: [String]
  /// The parameters and their defaults. A type can't change them; dismissals tune them (risk R2).
  public let parameters: [String: Double]
}

public enum ClockLibrary {
  public static let all: [ClockDefinition] = [
    ClockDefinition(
      name: "saveBattery",
      summary: "The save battery in a cartridge is running out",
      reads: ["field saveBattery (date fitted)", "spine year"],
      parameters: ["lifespanYears": 25, "warnYearsBefore": 3]
    ),
    ClockDefinition(
      name: "discRot",
      summary: "A disc from a known bad period is due a check",
      reads: ["spine year", "event serviced"],
      parameters: ["checkEveryYears": 5]
    ),
    ClockDefinition(
      name: "mediaRot",
      summary: "Tape or floppy media needs playing or checking",
      reads: ["spine year", "event serviced"],
      parameters: ["checkEveryYears": 2]
    ),
    ClockDefinition(
      name: "codeExpiry",
      summary: "A download code reaches its expiry date",
      reads: ["field expires (date)"],
      parameters: ["warnDaysBefore": 60]
    ),
    ClockDefinition(
      name: "drinkingWindow",
      summary: "A bottle is entering, at, or past its drinking window",
      reads: ["field drinkingWindow (yearRange)"],
      parameters: ["warnYearsBefore": 1]
    ),
    ClockDefinition(
      name: "serviceRisk",
      summary: "It's been a long time since the last service",
      reads: ["field lastServiced (event)", "event serviced"],
      parameters: ["intervalMonths": 24]
    ),
  ]

  public static func definition(_ name: String) -> ClockDefinition? {
    all.first { $0.name == name }
  }
}

/// A type's or a subtype's use of a clock: its name, and whether it's held back. `discRot-pending` in a file is the
/// disc-rot clock held pending evidence (page 51): named, shown nowhere, until the evidence is in.
public struct ClockReference: Hashable, Sendable {
  public let name: String
  public let isPending: Bool

  static let pendingSuffix = "-pending"

  public init(_ written: String) {
    if written.hasSuffix(Self.pendingSuffix) {
      name = String(written.dropLast(Self.pendingSuffix.count))
      isPending = true
    } else {
      name = written
      isPending = false
    }
  }

  public var definition: ClockDefinition? { ClockLibrary.definition(name) }
}

/// The signature renderers the app owns (One Roof, section 09). A type picks up to two; it can't invent one.
public enum SignatureRenderer: String, CaseIterable, Hashable, Sendable {
  /// Condition per part on one scale: cart, box, manual.
  case ladder
  /// Which parts are present, as slots.
  case set
  /// A cumulative estimate, as a dial (artwork's light exposure).
  case gauge
  /// The last test as LEDs (retro computers).
  case panel
  /// The machine and what hangs off it.
  case map
  /// What's inside a bundle (48: "the existing case signature").
  case `case`
}

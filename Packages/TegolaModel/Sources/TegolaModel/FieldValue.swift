public import Foundation

/// Where a value on an object lives: a spine role, the condition, a ladder axis, the notes, or a field of the type,
/// subtype or item level by its key. One key space, so an edit, a lookup and an import all say which values they
/// touch the same way (PD-050: `edited` carries the changed keys only).
public enum FieldKey: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
  case title, subtitle, year, acquired, paid, value
  case condition
  /// One axis of the condition ladder, by its scale field's key.
  case axis(String)
  case notes
  case field(String)

  public var description: String {
    switch self {
    case .title: "title"
    case .subtitle: "subtitle"
    case .year: "year"
    case .acquired: "acquired"
    case .paid: "paid"
    case .value: "value"
    case .condition: "condition"
    case .axis(let key): "axis.\(key)"
    case .notes: "notes"
    case .field(let key): "field.\(key)"
    }
  }

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.description < rhs.description }

  /// The spine roles money lives in. With the money switch off they're still recorded (story 165).
  public var isMoney: Bool { self == .paid || self == .value }
}

/// One value on an object. Its shape follows the field kind; the kind decides the control (PLAN §3.3).
public enum FieldValue: Hashable, Sendable, Codable {
  /// Text, and a choice's picked option.
  case text(String)
  case number(Double)
  case flag(Bool)
  case date(Date)
  case year(Int)
  case yearRange(from: Int, to: Int)
  case money(Money)
  /// A set's present slots, or a multi-choice.
  case options([String])
  /// A list's or a log's entries, each keyed by the field's entry parts ("date", "note").
  case entries([[String: String]])
  case photo(PhotoID)
}

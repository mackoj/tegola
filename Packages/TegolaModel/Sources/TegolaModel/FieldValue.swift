public import Foundation

/// Where a value on an object lives: a spine role, the condition, a ladder axis, the notes, or a field of the type,
/// subtype or item level by its key. One key space, so an edit, a lookup and an import all say which values they
/// touch the same way (PD-050: `edited` carries the changed keys only).
public enum FieldKey: Hashable, Sendable, Codable, Comparable, CustomStringConvertible, CodingKeyRepresentable {
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

  /// Reads a key as `description` writes it: the stored form, in the log and the projection.
  public init?(description: String) {
    switch description {
    case "title": self = .title
    case "subtitle": self = .subtitle
    case "year": self = .year
    case "acquired": self = .acquired
    case "paid": self = .paid
    case "value": self = .value
    case "condition": self = .condition
    case "notes": self = .notes
    default:
      if description.hasPrefix("axis.") {
        self = .axis(String(description.dropFirst(5)))
      } else if description.hasPrefix("field.") {
        self = .field(String(description.dropFirst(6)))
      } else {
        return nil
      }
    }
  }

  public init(from decoder: any Decoder) throws {
    let text = try decoder.singleValueContainer().decode(String.self)
    guard let key = FieldKey(description: text) else {
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "unknown key \(text)"))
    }
    self = key
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }

  public var codingKey: any CodingKey { StringKey(description) }

  public init?<T: CodingKey>(codingKey: T) {
    self.init(description: codingKey.stringValue)
  }

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

struct StringKey: CodingKey {
  let stringValue: String
  init(_ value: String) { stringValue = value }
  init?(stringValue: String) { self.stringValue = stringValue }
  var intValue: Int? { nil }
  init?(intValue: Int) { nil }
}

extension FieldValue {
  /// The value as stored: a list or log keeps only entries with something in them, and an empty one is no value at
  /// all, so tapping "+ Add entry" and saving records nothing.
  public var normalized: FieldValue? {
    switch self {
    case .entries(let entries):
      let kept = entries.map { $0.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        .filter { !$0.isEmpty }
      return kept.isEmpty ? nil : .entries(kept)
    case .options(let options):
      return options.isEmpty ? nil : self
    default:
      return self
    }
  }
}

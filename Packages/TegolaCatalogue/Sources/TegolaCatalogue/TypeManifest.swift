/// One type file, as far as M1 reads it: identity, nouns, the bulk rule, the spine labels, the condition scale and
/// the fields. Subtypes, signatures, clocks and the resolver arrive in M2 (tasks/plan.md).
public struct TypeManifest: Decodable, Hashable, Sendable, Identifiable {
  public struct ID: RawRepresentable, Hashable, Sendable, Decodable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public init(from decoder: any Decoder) throws {
      rawValue = try decoder.singleValueContainer().decode(String.self)
    }
  }

  public struct Names: Decodable, Hashable, Sendable {
    /// The hobby, e.g. "Music". Thing has none.
    public let hobby: String?
    /// One object, e.g. "Release".
    public let singular: String
    public let plural: String
    /// The collection a first object of this type creates, e.g. "My Music" (PD-137).
    public let collection: String
  }

  /// Whether a duplicate is a new object or a count on one object (PD-020). Thing asks (PD-151).
  public enum BulkRule: String, Decodable, Hashable, Sendable {
    case rows, quantity, ask
  }

  /// The type's labels for the fixed spine roles (PD-129). Absent roles use the app's own word.
  public struct Spine: Decodable, Hashable, Sendable {
    public let title: String
    public let subtitle: String?
    public let year: String?
    public let acquired: String?
    public let paid: String?
    public let value: String?
  }

  public let id: ID
  public let version: Int
  public let name: Names
  public let mark: String
  public let icon: String
  public let duplicates: BulkRule
  public let spine: Spine
  /// The hobby's own grading words, best first (PD-014).
  public let conditions: [String]
  public let fields: [Field]
  /// The subtypes, as far as M1 reads them: each key and the fields its presets fill or narrow (page 48). The full
  /// subtype model and the resolver arrive in M2.
  public let subtypes: [Subtype]

  public struct Subtype: Decodable, Hashable, Sendable {
    public let key: String
    public let presetKeys: Set<String>

    enum CodingKeys: String, CodingKey { case key, presets }
    static let knownKeys: Set<String> = ["key", "label", "presets", "adds"]

    public init(from decoder: any Decoder) throws {
      try rejectUnknownKeys(in: decoder, known: Self.knownKeys)
      let container = try decoder.container(keyedBy: CodingKeys.self)
      key = try container.decode(String.self, forKey: .key)
      // Absent presets are fine; malformed ones are an error, not an empty set.
      if container.contains(.presets) {
        let presets = try container.nestedContainer(keyedBy: AnyKey.self, forKey: .presets)
        presetKeys = Set(presets.allKeys.map(\.stringValue))
      } else {
        presetKeys = []
      }
    }
  }

  enum CodingKeys: String, CodingKey {
    case id, version, name, mark, icon, duplicates, spine, conditions, fields, subtypes
  }

  /// Every top-level key a type file may use. M1 reads some of them; the rest are read from M2 on, but a key outside
  /// this list is a typo and fails decoding (D-30).
  static let knownKeys: Set<String> = [
    "id", "version", "name", "mark", "icon", "gradient", "duplicates", "consumable", "composite", "spine", "conditions",
    "allowMissing", "workingState", "attribution", "lookup", "searchable", "related", "placeLabel", "fields",
    "requiredFields", "customFields", "signatures", "subtypes", "mediumRules", "mediaRules", "kindRules", "supersedes",
  ]

  public init(from decoder: any Decoder) throws {
    try rejectUnknownKeys(in: decoder, known: Self.knownKeys)
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(ID.self, forKey: .id)
    version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    name = try container.decode(Names.self, forKey: .name)
    mark = try container.decode(LossyString.self, forKey: .mark).value
    icon = try container.decode(String.self, forKey: .icon)
    duplicates = try container.decode(BulkRule.self, forKey: .duplicates)
    spine = try container.decode(Spine.self, forKey: .spine)
    conditions = try container.decode([LossyString].self, forKey: .conditions).map(\.value)
    fields = try container.decode([Field].self, forKey: .fields)
    subtypes = try container.decodeIfPresent([Subtype].self, forKey: .subtypes) ?? []
  }
}

/// Fails decoding when a mapping has a key outside `known`: `requried: true` must not decode as an optional field.
func rejectUnknownKeys(in decoder: any Decoder, known: Set<String>) throws {
  let keys = try decoder.container(keyedBy: AnyKey.self).allKeys.map(\.stringValue)
  if let unknown = keys.filter({ !known.contains($0) }).sorted().first {
    throw DecodingError.dataCorrupted(
      .init(codingPath: decoder.codingPath, debugDescription: "unknown key \"\(unknown)\"")
    )
  }
}

/// A coding key for mappings whose keys are data (subtype presets).
struct AnyKey: CodingKey {
  let stringValue: String
  init(stringValue: String) { self.stringValue = stringValue }
  var intValue: Int? { nil }
  init?(intValue: Int) { nil }
}

extension TypeManifest {
  /// One typed fact beyond the spine. Its kind decides the control, the sort and the search (CONTEXT: Field).
  public struct Field: Decodable, Hashable, Sendable {
    public let key: String
    public let label: String
    public let kind: FieldKind
    public let options: [String]
    public let unit: String?
    /// Filled by a lookup when one runs; badged AUTO until the collector touches it (PD-042).
    public let isAuto: Bool
    public let isRequired: Bool

    enum CodingKeys: String, CodingKey {
      case key, label, type, options, unit, auto, required
    }
    static let knownKeys: Set<String> = [
      "key", "label", "type", "note", "sample", "options", "default", "showIf", "multiline", "unit", "entry", "auto",
      "required", "unlocks", "ladderAxis", "slotsFrom", "precision", "depth", "allowNV", "peak",
    ]

    public init(from decoder: any Decoder) throws {
      try rejectUnknownKeys(in: decoder, known: Self.knownKeys)
      let container = try decoder.container(keyedBy: CodingKeys.self)
      key = try container.decode(String.self, forKey: .key)
      label = try container.decode(String.self, forKey: .label)
      kind = try container.decode(FieldKind.self, forKey: .type)
      options = try container.decodeIfPresent([LossyString].self, forKey: .options)?.map(\.value) ?? []
      unit = try container.decodeIfPresent(LossyString.self, forKey: .unit)?.value
      isAuto = try container.decodeIfPresent(Bool.self, forKey: .auto) ?? false
      isRequired = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
    }
  }
}

/// The closed set of field kinds. A type file may only use these; the app owns the controls (PD-010).
public enum FieldKind: String, CaseIterable, Hashable, Sendable, Decodable {
  case text, number, choice, yesNo, date, year, yearRange, event, list, log, photo, scale, set, composite, dims,
    money, files

  /// The kinds a collector may give their own fields (PD-130). The rest are what an official type earns.
  public static let collectorKinds: Set<FieldKind> = [.text, .number, .choice, .yesNo, .date, .event, .photo]

  /// Spellings the type files use for the same kind. Kept here, in one place, so a typo is a decoding error rather
  /// than a silent fallback to text (clctn's decoder fell back, which hid mistakes).
  static let aliases: [String: FieldKind] = ["int": .number, "bool": .yesNo]

  public init(from decoder: any Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    guard let kind = FieldKind(rawValue: raw) ?? Self.aliases[raw] else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "unknown field kind \"\(raw)\"")
      )
    }
    self = kind
  }
}

/// A scalar YAML value read as text: `45` and `"45"` are the same option on a choice field.
struct LossyString: Decodable, Hashable {
  let value: String

  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let string = try? container.decode(String.self) {
      value = string
    } else if let int = try? container.decode(Int.self) {
      value = String(int)
    } else if let double = try? container.decode(Double.self) {
      value = String(double)
    } else {
      value = String(try container.decode(Bool.self))
    }
  }
}

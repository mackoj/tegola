/// One type file: the hobby's nouns (PLAN §3.3). Schema v1, frozen from `video-game.yml` and `video-media.yml` (page 52,
/// P0); `schema/type.schema.json` describes the same shape for people writing a type file.
public struct TypeManifest: Decodable, Hashable, Sendable, Identifiable {
  public struct ID: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public init(from decoder: any Decoder) throws {
      rawValue = try decoder.singleValueContainer().decode(String.self)
    }
    public func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      try container.encode(rawValue)
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

  /// How a type's objects are identified when they're captured (PLAN §7).
  public struct Lookup: Decodable, Hashable, Sendable {
    /// The field that identifies a copy: `barcode`, `isbn`, `catalogueNumber`, … or `none`. Nil when it varies per
    /// subtype (video games: the platform decides).
    public let identifier: String?
    /// How the identifier's format is chosen when it isn't one pattern: `per-platform`, `per-manufacturer`.
    public let identifierPattern: String?
    public let symbologies: [String]
    public let providers: [String]
    /// A bundled corpus the lookup searches first; `none` for no corpus.
    public let localCorpus: String?
    /// The fields text recognition fills from a photo.
    public let ocrFields: [String]

    enum CodingKeys: String, CodingKey {
      case identifier, identifierPattern, symbologies, providers, localCorpus, ocrFields
    }

    public init(from decoder: any Decoder) throws {
      try rejectUnknownKeys(in: decoder, known: Set(CodingKeys.allNames))
      let container = try decoder.container(keyedBy: CodingKeys.self)
      identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
      identifierPattern = try container.decodeIfPresent(String.self, forKey: .identifierPattern)
      symbologies = try container.decodeIfPresent([String].self, forKey: .symbologies) ?? []
      providers = try container.decodeIfPresent([String].self, forKey: .providers) ?? []
      localCorpus = try container.decodeIfPresent(String.self, forKey: .localCorpus)
      ocrFields = try container.decodeIfPresent([String].self, forKey: .ocrFields) ?? []
    }
  }

  /// One signature: a renderer from the app's kit, bound to the fields that feed it (One Roof, section 09). Two at
  /// most per type.
  public struct Signature: Decodable, Hashable, Sendable {
    /// The renderer's name, checked against `SignatureRenderer` by validation.
    public let renderer: String
    /// The scale fields a ladder reads, best-graded part first.
    public internal(set) var axes: [String]
    /// The field the renderer reads, for every renderer but the ladder.
    public let binds: String?
    /// For a renderer over a log, the entry kind it reads (retro computers' panel reads `test` entries).
    public let entryKind: String?

    enum CodingKeys: String, CodingKey { case renderer, axes, binds, entryKind }

    public init(from decoder: any Decoder) throws {
      try rejectUnknownKeys(in: decoder, known: Set(CodingKeys.allNames))
      let container = try decoder.container(keyedBy: CodingKeys.self)
      renderer = try container.decode(String.self, forKey: .renderer)
      axes = try container.decodeIfPresent([String].self, forKey: .axes) ?? []
      binds = try container.decodeIfPresent(String.self, forKey: .binds)
      entryKind = try container.decodeIfPresent(String.self, forKey: .entryKind)
    }
  }

  /// An older type this one replaces, and how its fields map (page 37). Absent fields survive as own fields, so a
  /// migration never loses a value.
  public struct Supersession: Decodable, Hashable, Sendable {
    /// `official/retro-game@1`.
    public let type: String
    /// Values every migrated object gets (vinyl → `medium: Vinyl`).
    public let sets: [String: String]
    /// Old key → new key, or `derived` for a key the new type computes instead of storing.
    public let fields: [String: String]

    enum CodingKeys: String, CodingKey { case type, sets, fields }

    public init(from decoder: any Decoder) throws {
      try rejectUnknownKeys(in: decoder, known: Set(CodingKeys.allNames))
      let container = try decoder.container(keyedBy: CodingKeys.self)
      type = try container.decode(String.self, forKey: .type)
      sets = try container.decodeIfPresent([String: LossyString].self, forKey: .sets)?.mapValues(\.value) ?? [:]
      fields = try container.decodeIfPresent([String: String].self, forKey: .fields) ?? [:]
    }
  }

  public let id: ID
  public let version: Int
  public let name: Names
  public let mark: String
  public let icon: String
  /// The two palette names a collection cover blends.
  public let gradient: [String]
  public let duplicates: BulkRule
  /// Objects that get used up: wine is drunk, and an opened bottle leaves the count (PD-021).
  public let isConsumable: Bool
  /// Objects made of parts that are objects of their own (retro computers, v1.x).
  public let isComposite: Bool
  public let spine: Spine
  /// The hobby's own grading words, best first (PD-014).
  public let conditions: [String]
  /// Whether `Missing` is a step on every axis, so completeness and condition are one question (43).
  public let allowMissing: Bool
  /// A second scale for whether the thing works (retro computers).
  public let workingState: [String]
  /// The attribution words a type grades authorship with (artwork).
  public let attribution: [String]
  public let lookup: Lookup?
  /// The fields search reads, spine roles included.
  public let searchable: [String]
  /// The fields "more like this" groups by.
  public let related: [String]
  /// The place slot's label, when the type has its own ("Where it is").
  public let placeLabel: String?
  public let fields: [Field]
  /// Fields every object of this type must have before it's saved (Thing: a title).
  public let requiredFields: [String]
  /// Whether a collector may add own fields to this type's objects (PD-130).
  public let allowsOwnFields: Bool
  public let signatures: [Signature]
  /// Clocks from the app's library every object of the type runs, whatever its subtype.
  public let clocks: [String]
  public let subtypes: [Subtype]
  public let supersedes: [Supersession]

  enum CodingKeys: String, CodingKey {
    case id, version, name, mark, icon, gradient, duplicates, consumable, composite, spine, conditions, allowMissing,
      workingState, attribution, lookup, searchable, related, placeLabel, fields, requiredFields, customFields,
      signatures, clocks, subtypes, supersedes
  }

  public init(from decoder: any Decoder) throws {
    try rejectUnknownKeys(in: decoder, known: Set(CodingKeys.allNames))
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(ID.self, forKey: .id)
    version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
    name = try container.decode(Names.self, forKey: .name)
    mark = try container.decode(LossyString.self, forKey: .mark).value
    icon = try container.decode(String.self, forKey: .icon)
    gradient = try container.decodeIfPresent([String].self, forKey: .gradient) ?? []
    duplicates = try container.decode(BulkRule.self, forKey: .duplicates)
    isConsumable = try container.decodeIfPresent(Bool.self, forKey: .consumable) ?? false
    isComposite = try container.decodeIfPresent(Bool.self, forKey: .composite) ?? false
    spine = try container.decode(Spine.self, forKey: .spine)
    conditions = try container.decode([LossyString].self, forKey: .conditions).map(\.value)
    allowMissing = try container.decodeIfPresent(Bool.self, forKey: .allowMissing) ?? false
    workingState = try container.decodeIfPresent([String].self, forKey: .workingState) ?? []
    attribution = try container.decodeIfPresent([String].self, forKey: .attribution) ?? []
    lookup = try container.decodeIfPresent(Lookup.self, forKey: .lookup)
    searchable = try container.decodeIfPresent([String].self, forKey: .searchable) ?? []
    related = try container.decodeIfPresent([String].self, forKey: .related) ?? []
    placeLabel = try container.decodeIfPresent(String.self, forKey: .placeLabel)
    fields = try container.decode([Field].self, forKey: .fields)
    requiredFields = try container.decodeIfPresent([String].self, forKey: .requiredFields) ?? []
    allowsOwnFields = try container.decodeIfPresent(Bool.self, forKey: .customFields) ?? false
    signatures = try container.decodeIfPresent([Signature].self, forKey: .signatures) ?? []
    clocks = try container.decodeIfPresent([String].self, forKey: .clocks) ?? []
    subtypes = try container.decodeIfPresent([Subtype].self, forKey: .subtypes) ?? []
    supersedes = try container.decodeIfPresent([Supersession].self, forKey: .supersedes) ?? []
  }
}

extension TypeManifest {
  /// One level below a type, keyed on platform for games and format for music and film (page 48). It inherits
  /// everything, and can add fields, preset or hide a field, narrow a choice, add ladder parts and name clocks.
  public struct Subtype: Decodable, Hashable, Sendable {
    public let key: String
    public let label: String
    /// What the subtype does to the parent's fields, by field key.
    public let presets: [String: Preset]
    /// The parts the set signature counts, in order (Saturn: case, manual, disc, spine card).
    public let parts: [String]
    /// Clocks from the app's library, by name. Written `clock:` in a file; `none` means none.
    public let clocks: [String]
    /// The identifiers a capture reads for this subtype, in order of preference.
    public let lookup: [String]
    /// Fields only this subtype's collectors care about.
    public let adds: [Field]

    /// What a preset does to one parent field.
    public enum Preset: Hashable, Sendable {
      /// The field doesn't apply, so it's hidden (VHS has no region code).
      case hidden
      /// The field has one possible value: it's filled with it and hidden (Saturn → media: Optical disc).
      case value(String)
      /// The choice offers only these options (DVD's region codes).
      case options([String])
    }

    /// Keys of a `presets` mapping that aren't parent fields.
    static let reservedPresetKeys: Set<String> = ["parts", "clock", "lookup"]

    enum CodingKeys: String, CodingKey { case key, label, presets, adds }

    public init(from decoder: any Decoder) throws {
      try rejectUnknownKeys(in: decoder, known: Set(CodingKeys.allNames))
      let container = try decoder.container(keyedBy: CodingKeys.self)
      key = try container.decode(String.self, forKey: .key)
      label = try container.decode(String.self, forKey: .label)
      adds = try container.decodeIfPresent([Field].self, forKey: .adds) ?? []
      var presets: [String: Preset] = [:]
      var parts: [String] = []
      var clocks: [String] = []
      var lookup: [String] = []
      // Absent presets are fine; malformed ones are an error, not an empty set.
      if container.contains(.presets) {
        let mapping = try container.nestedContainer(keyedBy: AnyKey.self, forKey: .presets)
        for presetKey in mapping.allKeys {
          let values = try mapping.decode(OneOrMany.self, forKey: presetKey).values
          switch presetKey.stringValue {
          case "parts": parts = values
          case "clock": clocks = values == ["none"] ? [] : values
          case "lookup": lookup = values
          default:
            let preset: Preset
            if case .one(let value) = try mapping.decode(OneOrMany.self, forKey: presetKey) {
              preset = value == "hidden" ? .hidden : .value(value)
            } else {
              preset = .options(values)
            }
            presets[presetKey.stringValue] = preset
          }
        }
      }
      self.presets = presets
      self.parts = parts
      self.clocks = clocks
      self.lookup = lookup
    }
  }
}

extension TypeManifest {
  /// One typed fact beyond the spine. Its kind decides the control, the sort and the search (CONTEXT: Field).
  public struct Field: Decodable, Hashable, Sendable {
    public let key: String
    public let label: String
    public let kind: FieldKind
    public internal(set) var options: [String]
    public let unit: String?
    /// Filled by a lookup when one runs; badged AUTO until the collector touches it (PD-042).
    public let isAuto: Bool
    public let isRequired: Bool
    /// The value a new object starts with.
    public let defaultValue: String?
    /// For a list or a log: the parts of one entry ("date, note, finished").
    public let entry: [String]
    /// For a scale that feeds the ladder: its position, from 1.
    public let ladderAxis: Int?
    /// For a set: where its slots come from (`subtype`: the subtype's parts).
    public let slotsFrom: String?
    /// For a yes/no: the fields it reveals when it's yes (artwork's `editioned`).
    public let unlocks: [String]
    /// A condition on the field's own value for showing it ("> 1": Thing's quantity).
    public let showIf: String?
    public let isMultiline: Bool
    /// On a subtype's addition: the parent field it stands in for (CED's caddy for the case). See D-36.
    public let replaces: String?

    enum CodingKeys: String, CodingKey {
      case key, label, type, options, unit, auto, required, `default`, entry, ladderAxis, slotsFrom, unlocks, showIf,
        multiline, replaces
    }
    /// Keys a file may use that the app doesn't read: design notes, samples, and display hints no screen uses yet.
    static let unreadKeys: Set<String> = ["note", "sample", "precision", "depth", "allowNV", "peak", "unique"]

    public init(from decoder: any Decoder) throws {
      try rejectUnknownKeys(in: decoder, known: Set(CodingKeys.allNames).union(Self.unreadKeys))
      let container = try decoder.container(keyedBy: CodingKeys.self)
      key = try container.decode(String.self, forKey: .key)
      label = try container.decode(String.self, forKey: .label)
      kind = try container.decode(FieldKind.self, forKey: .type)
      options = try container.decodeIfPresent([LossyString].self, forKey: .options)?.map(\.value) ?? []
      unit = try container.decodeIfPresent(LossyString.self, forKey: .unit)?.value
      isAuto = try container.decodeIfPresent(Bool.self, forKey: .auto) ?? false
      isRequired = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
      defaultValue = try container.decodeIfPresent(LossyString.self, forKey: .default)?.value
      entry = try container.decodeIfPresent([String].self, forKey: .entry) ?? []
      ladderAxis = try container.decodeIfPresent(Int.self, forKey: .ladderAxis)
      slotsFrom = try container.decodeIfPresent(String.self, forKey: .slotsFrom)
      unlocks = try container.decodeIfPresent([String].self, forKey: .unlocks) ?? []
      showIf = try container.decodeIfPresent(String.self, forKey: .showIf)
      isMultiline = try container.decodeIfPresent(Bool.self, forKey: .multiline) ?? false
      replaces = try container.decodeIfPresent(String.self, forKey: .replaces)
    }
  }
}

/// The closed set of field kinds. A type file may only use these; the app owns the controls (PD-010).
public enum FieldKind: String, CaseIterable, Hashable, Sendable, Codable {
  case text, number, choice, yesNo, date, year, yearRange, event, list, log, photo, scale, set, composite, dims,
    money, files

  /// The kinds a collector may give their own fields (PD-130). The rest are what an official type earns.
  public static let collectorKinds: Set<FieldKind> = [.text, .number, .choice, .yesNo, .date, .event, .photo]

  /// Spellings the type files use for the same kind. Kept here, in one place, so a typo is a decoding error rather
  /// than a silent fallback to text (clctn's decoder fell back, which hid mistakes). See D-30.
  static let aliases: [String: FieldKind] = ["int": .number, "bool": .yesNo, "enum": .choice]

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

/// The item level (`Item/item.yml`): the fields every type inherits, hidden until the object has a value (page 48,
/// section 00).
public struct ItemLevel: Decodable, Hashable, Sendable {
  public let fields: [TypeManifest.Field]

  public init(fields: [TypeManifest.Field]) {
    self.fields = fields
  }

  public static let none = ItemLevel(fields: [])
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

extension CodingKey where Self: CaseIterable {
  static var allNames: [String] { allCases.map(\.stringValue) }
}

extension TypeManifest.Lookup.CodingKeys: CaseIterable {}
extension TypeManifest.Signature.CodingKeys: CaseIterable {}
extension TypeManifest.Supersession.CodingKeys: CaseIterable {}
extension TypeManifest.CodingKeys: CaseIterable {}
extension TypeManifest.Subtype.CodingKeys: CaseIterable {}
extension TypeManifest.Field.CodingKeys: CaseIterable {}

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

/// A preset value: one scalar, or a list of them.
enum OneOrMany: Decodable, Hashable {
  case one(String)
  case many([String])

  var values: [String] {
    switch self {
    case .one(let value): [value]
    case .many(let values): values
    }
  }

  init(from decoder: any Decoder) throws {
    if let list = try? decoder.singleValueContainer().decode([LossyString].self) {
      self = .many(list.map(\.value))
    } else {
      self = .one(try decoder.singleValueContainer().decode(LossyString.self).value)
    }
  }
}

/// A type as one object of it sees it: the parent's fields with a subtype's presets and additions applied (page 48,
/// page 52 P0). Every screen and the import read fields through this, never through the manifest directly.
public struct EffectiveType: Hashable, Sendable {
  public let type: TypeManifest.ID
  /// Nil for an object of the parent type alone.
  public let subtype: String?
  /// Every field, hidden ones included (an import may still set a preset value), in the order the edit form shows
  /// them: the parent's, then the subtype's additions.
  public let fields: [EffectiveField]
  /// The signatures, with an axis a subtype replaced swapped for its replacement.
  public let signatures: [TypeManifest.Signature]
  /// The clocks from the library this object runs.
  public let clocks: [String]
  /// The identifiers a capture reads, in order of preference.
  public let lookup: [String]
  public let conditions: [String]

  /// The fields a collector sees and edits.
  public var visibleFields: [EffectiveField] { fields.filter { !$0.isHidden } }

  public func field(_ key: String) -> EffectiveField? { fields.first { $0.key == key } }
}

/// One field of an `EffectiveType`.
public struct EffectiveField: Hashable, Sendable {
  public enum Origin: Hashable, Sendable {
    /// From the item level every type inherits (T2.4).
    case item
    case type
    case subtype
  }

  /// The field, with its options narrowed by the subtype (or, for a set, its slots from the subtype's parts).
  public let field: TypeManifest.Field
  public let origin: Origin
  /// Hidden by a preset, or replaced by a subtype's addition. A hidden field keeps its preset value.
  public let isHidden: Bool
  /// The value a preset fills in.
  public let presetValue: String?

  public var key: String { field.key }
}

public enum ResolveError: Error, Equatable, Sendable {
  case unknownSubtype(type: TypeManifest.ID, subtype: String)
}

extension TypeManifest {
  /// The type as an object of `subtype` (or of the parent alone, when nil) sees it.
  public func resolve(subtype key: String?) throws(ResolveError) -> EffectiveType {
    guard let key else {
      return EffectiveType(
        type: id,
        subtype: nil,
        fields: fields.map { EffectiveField(field: $0, origin: .type, isHidden: false, presetValue: nil) },
        signatures: signatures,
        clocks: [],
        lookup: lookup?.identifier.map { [$0] } ?? [],
        conditions: conditions
      )
    }
    guard let subtype = subtypes.first(where: { $0.key == key }) else {
      throw .unknownSubtype(type: id, subtype: key)
    }
    let replacements = Dictionary(subtype.adds.compactMap { add in add.replaces.map { ($0, add) } }) { first, _ in first
    }
    let replaced = replacements.mapValues(\.key)
    var resolved: [EffectiveField] = []
    for field in fields {
      let preset = subtype.presets[field.key]
      var narrowed = field
      var presetValue: String?
      var isHidden = replaced[field.key] != nil
      switch preset {
      case .hidden: isHidden = true
      case .value(let value):
        isHidden = true
        presetValue = value
      case .options(let options): narrowed = field.with(options: options)
      case nil: break
      }
      if field.kind == .set, field.slotsFrom == "subtype", !subtype.parts.isEmpty {
        narrowed = narrowed.with(options: subtype.parts)
      }
      resolved.append(EffectiveField(field: narrowed, origin: .type, isHidden: isHidden, presetValue: presetValue))
      // A replacement takes the place of the field it stands in for (D-36).
      if let replacement = replacements[field.key] {
        resolved.append(EffectiveField(field: replacement, origin: .subtype, isHidden: false, presetValue: nil))
      }
    }
    resolved += subtype.adds.filter { $0.replaces == nil }.map {
      EffectiveField(field: $0, origin: .subtype, isHidden: false, presetValue: nil)
    }
    let identifiers = subtype.lookup.isEmpty ? (lookup?.identifier.map { [$0] } ?? []) : subtype.lookup
    return EffectiveType(
      type: id,
      subtype: subtype.key,
      fields: resolved,
      signatures: signatures.map { $0.replacingAxes(replaced) },
      clocks: subtype.clocks,
      lookup: identifiers,
      conditions: conditions
    )
  }
}

extension TypeManifest.Field {
  func with(options: [String]) -> Self {
    var copy = self
    copy.options = options
    return copy
  }
}

extension TypeManifest.Signature {
  func replacingAxes(_ replaced: [String: String]) -> Self {
    var copy = self
    copy.axes = axes.map { replaced[$0] ?? $0 }
    return copy
  }
}

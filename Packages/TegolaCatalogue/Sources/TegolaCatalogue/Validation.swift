/// One rule a type file breaks. A bad file fails a test, never the app (PLAN §3.3).
public struct ManifestProblem: Hashable, Sendable, CustomStringConvertible {
  public let type: TypeManifest.ID
  public let message: String

  public var description: String { "\(type.rawValue): \(message)" }
}

extension TypeManifest {
  /// Every rule a type file must follow (PLAN §3.3, page 48). Empty for a valid file.
  public var problems: [ManifestProblem] {
    var problems: [String] = []
    if id.rawValue.wholeMatch(of: /[a-z0-9]+(-[a-z0-9]+)*/) == nil {
      problems.append("id must be kebab-case ASCII: lowercase letters and digits, single hyphens between words")
    }
    let keys = fields.map(\.key)
    for key in Set(keys) where keys.filter({ $0 == key }).count > 1 {
      problems.append("field key \"\(key)\" appears more than once")
    }
    if conditions.count < 2 {
      problems.append("a condition scale needs at least two steps")
    }
    if let missing = conditions.firstIndex(of: "Missing"), missing != conditions.count - 1 {
      problems.append("\"Missing\" must be the last condition step (PD-014)")
    }
    if Set(conditions).count != conditions.count {
      problems.append("condition steps must be unique")
    }
    // A choice with no options of its own is valid only when every subtype presets them (page 48: a subtype may
    // narrow a choice). Without subtypes, nobody could ever pick a value.
    for field in fields where field.kind == .choice && field.options.isEmpty {
      let presetEverywhere =
        !subtypes.isEmpty
        && subtypes.allSatisfy {
          if case .options = $0.presets[field.key] { true } else { false }
        }
      if !presetEverywhere {
        problems.append("choice field \"\(field.key)\" has no options and isn't narrowed by every subtype")
      }
    }
    // The same rule for a set whose slots come from the subtype: with no slots of its own, an object without a
    // subtype that names parts would have nothing to count (D-36).
    for field in fields where field.kind == .set && field.slotsFrom == "subtype" && field.options.isEmpty {
      if subtypes.isEmpty || !subtypes.allSatisfy({ !$0.parts.isEmpty }) {
        problems.append("set field \"\(field.key)\" has no slots and isn't given parts by every subtype")
      }
    }
    let named = clocks + subtypes.flatMap(\.clocks)
    for name in Set(named).sorted() where ClockReference(name).definition == nil {
      problems.append("clock \"\(name)\" isn't in the app's library: a type can't define its own")
    }
    problems += signatureProblems
    problems += subtypeProblems
    return problems.map { ManifestProblem(type: id, message: $0) }
  }

  /// Subtypes with more additions than page 48's review threshold: flagged for review as a possible type of their
  /// own, never blocked (48, Q3).
  public var subtypesForReview: [String] {
    subtypes.filter { $0.adds.count > Self.subtypeReviewThreshold }.map(\.key)
  }

  static let subtypeReviewThreshold = 5

  private var signatureProblems: [String] {
    var problems: [String] = []
    if signatures.count > 2 {
      problems.append("a type has at most two signatures (PD-017)")
    }
    let byKey = Dictionary(fields.map { ($0.key, $0) }) { first, _ in first }
    for signature in signatures where SignatureRenderer(rawValue: signature.renderer) == nil {
      problems.append("signature renderer \"\(signature.renderer)\" isn't in the app's kit")
    }
    for signature in signatures {
      if signature.renderer == "ladder" {
        if signature.axes.isEmpty { problems.append("a ladder signature needs its axes") }
        for axis in signature.axes where byKey[axis]?.kind != .scale {
          problems.append("ladder axis \"\(axis)\" isn't a scale field of the type")
        }
      } else if let binds = signature.binds, signature.renderer == "set", byKey[binds]?.kind != .set {
        problems.append("set signature binds \"\(binds)\", which isn't a set field of the type")
      }
    }
    return problems
  }

  /// Page 48's rules: a subtype inherits everything and can only add nouns. It can add fields, preset or hide a field,
  /// narrow a choice and name parts; it can't redefine, remove or rename a parent field.
  private var subtypeProblems: [String] {
    var problems: [String] = []
    let byKey = Dictionary(fields.map { ($0.key, $0) }) { first, _ in first }
    let subtypeKeys = subtypes.map(\.key)
    for key in Set(subtypeKeys) where subtypeKeys.filter({ $0 == key }).count > 1 {
      problems.append("subtype \"\(key)\" appears more than once")
    }
    let hasSetSignature = signatures.contains { $0.renderer == "set" }
    for subtype in subtypes {
      let name = "subtype \"\(subtype.key)\""
      if subtype.key.wholeMatch(of: /[a-z0-9]+(-[a-z0-9]+)*/) == nil {
        problems.append("\(name): key must be kebab-case ASCII")
      }
      let added = subtype.adds.map(\.key)
      for key in Set(added) where added.filter({ $0 == key }).count > 1 {
        problems.append("\(name) adds \"\(key)\" more than once")
      }
      for add in subtype.adds {
        if byKey[add.key] != nil {
          problems.append("\(name) adds \"\(add.key)\", which the parent already has: a subtype can't redefine a field")
        }
        if let replaced = add.replaces {
          if let parent = byKey[replaced] {
            if parent.kind != add.kind {
              problems.append("\(name): \"\(add.key)\" replaces \"\(replaced)\" of another kind")
            }
          } else {
            problems.append("\(name): \"\(add.key)\" replaces \"\(replaced)\", which the parent doesn't have")
          }
        }
      }
      for (key, preset) in subtype.presets.sorted(by: { $0.key < $1.key }) {
        guard let parent = byKey[key] else {
          problems.append("\(name) presets \"\(key)\", which the parent doesn't have")
          continue
        }
        switch preset {
        case .hidden: break
        case .value(let value):
          if parent.kind == .choice, !parent.options.isEmpty, !parent.options.contains(value) {
            problems.append("\(name) presets \"\(key)\" to \"\(value)\", which isn't one of its options")
          }
        case .options(let options):
          if parent.kind != .choice && parent.kind != .set {
            problems.append("\(name) narrows \"\(key)\", which isn't a choice")
          } else if !parent.options.isEmpty, let extra = options.first(where: { !parent.options.contains($0) }) {
            problems.append("\(name) narrows \"\(key)\" with \"\(extra)\", which the parent doesn't offer")
          }
        }
      }
      if !subtype.parts.isEmpty && !hasSetSignature {
        problems.append("\(name) names parts, but the type has no set signature to count them")
      }
    }
    return problems
  }
}

extension Catalogue {
  /// Every manifest's problems, plus the rules across files: a type's field can't take an item-level key, because
  /// the item level means the same on every type (page 48).
  public var problems: [ManifestProblem] {
    let itemKeys = Set(item.fields.map(\.key))
    var problems = manifests.flatMap(\.problems)
    for manifest in manifests {
      let keys = manifest.fields.map(\.key) + manifest.subtypes.flatMap { $0.adds.map(\.key) }
      for key in Set(keys).intersection(itemKeys).sorted() {
        problems.append(ManifestProblem(type: manifest.id, message: "field \"\(key)\" is an item-level field"))
      }
    }
    return problems
  }
}

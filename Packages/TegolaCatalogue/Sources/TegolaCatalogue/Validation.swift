/// One rule a type file breaks. A bad file fails a test, never the app (PLAN §3.3).
public struct ManifestProblem: Hashable, Sendable, CustomStringConvertible {
  public let type: TypeManifest.ID
  public let message: String

  public var description: String { "\(type.rawValue): \(message)" }
}

extension TypeManifest {
  /// The M1 rules: the ones that hold for every file whatever later milestones add.
  public var problems: [ManifestProblem] {
    var problems: [String] = []
    if id.rawValue.isEmpty || id.rawValue.contains(where: { !($0.isLowercase || $0.isNumber || $0 == "-") }) {
      problems.append("id must be kebab-case")
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
      let presetEverywhere = !subtypes.isEmpty && subtypes.allSatisfy { $0.presetKeys.contains(field.key) }
      if !presetEverywhere {
        problems.append("choice field \"\(field.key)\" has no options and isn't preset by every subtype")
      }
    }
    return problems.map { ManifestProblem(type: id, message: $0) }
  }
}

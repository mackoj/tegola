/// The one chip every object carries, from five shared swatches (PD-016). Derived in the model, never in a view
/// (D-15); the rules that pick one arrive with the clocks in M4.
public enum ObjectStatus: String, CaseIterable, Hashable, Sendable, Codable, Comparable {
  case fine, good, watch, act, gone

  /// Most urgent first: the order a mixed shelf sorts by.
  static let urgency: [ObjectStatus] = [.act, .watch, .good, .fine, .gone]

  /// "Need attention" counts watch and act: the only number that crosses types (PD-016, CONTEXT).
  public var needsAttention: Bool { self == .watch || self == .act }

  public static func < (lhs: ObjectStatus, rhs: ObjectStatus) -> Bool {
    urgency.firstIndex(of: lhs)! < urgency.firstIndex(of: rhs)!
  }
}

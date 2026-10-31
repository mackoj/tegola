import Foundation

/// A place written as a path, "Cellar › Rack 3 › Bin 12": typing one on an object creates the nested places
/// (PD-053, story 104).
public struct PlacePath: Hashable, Sendable, CustomStringConvertible {
  /// The separator the app writes. Collectors may type `>` or `/` instead; both read as this.
  public static let separator: Character = "›"
  static let accepted: Set<Character> = ["›", ">", "/"]

  /// Outermost first. Never empty, and no component is blank.
  public let components: [String]

  /// Reads what a collector typed. Spaces around components are trimmed and empty components dropped, so
  /// "Cellar >  > Rack 3 " is "Cellar › Rack 3". Returns nil when nothing is left.
  public init?(typed text: String) {
    let parts = text.split(whereSeparator: { Self.accepted.contains($0) })
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    guard !parts.isEmpty else { return nil }
    components = parts
  }

  public var description: String { components.joined(separator: " \(Self.separator) ") }

  /// The place itself, without its parents ("Bin 12").
  public var name: String { components[components.count - 1] }

  /// Every enclosing path, outermost first: "Cellar", "Cellar › Rack 3", "Cellar › Rack 3 › Bin 12".
  public var lineage: [PlacePath] {
    (1...components.count).map { PlacePath(components: Array(components.prefix($0))) }
  }

  private init(components: [String]) {
    self.components = components
  }

  /// Two names that are probably the same place typed twice ("Rack 3" and "rack3", "Livng room"): equal once case,
  /// spaces and punctuation are ignored, or one edit apart with the same numbers. Numbers must match exactly: "Rack 3"
  /// and "Rack 4", or "Box 1" and "Box 12", are siblings, not typos. The app offers a merge and never does it alone
  /// (story 109, PD-151).
  public static func isNearDuplicate(_ a: String, _ b: String) -> Bool {
    let (x, y) = (normalised(a), normalised(b))
    guard x != y else { return true }
    guard numbers(in: x) == numbers(in: y) else { return false }
    return editDistanceAtMostOne(x, y)
  }

  /// The runs of digits in a name, in order: "Rack 3 Bin 12" gives ["3", "12"].
  static func numbers(in characters: [Character]) -> [String] {
    String(characters).split(whereSeparator: { !$0.isNumber }).map(String.init)
  }

  static func normalised(_ name: String) -> [Character] {
    Array(name.lowercased().filter { $0.isLetter || $0.isNumber })
  }

  static func editDistanceAtMostOne(_ x: [Character], _ y: [Character]) -> Bool {
    guard abs(x.count - y.count) <= 1, !x.isEmpty, !y.isEmpty else { return false }
    var (i, j, edits) = (0, 0, 0)
    while i < x.count && j < y.count {
      if x[i] == y[j] {
        i += 1
        j += 1
        continue
      }
      edits += 1
      if edits > 1 { return false }
      if x.count > y.count {
        i += 1
      } else if y.count > x.count {
        j += 1
      } else {
        i += 1
        j += 1
      }
    }
    return edits + (x.count - i) + (y.count - j) <= 1
  }
}

/// The five tabs (PD-117). Named `AppTab` because SwiftUI has its own `Tab` (iOS 18). and the order a collector chose for them (story 148). Shelf and Scan are welded in place;
/// the other three may be reordered among the remaining slots, and none can be hidden.
public enum AppTab: String, CaseIterable, Hashable, Sendable, Codable {
  case shelf, find, scan, activity, you

  /// Scan presents the camera rather than showing a screen of its own.
  public var presents: Bool { self == .scan }
}

public struct TabBarLayout: Hashable, Sendable, Codable {
  /// Left to right. Always all five tabs, Shelf first and Scan in the middle.
  public private(set) var order: [AppTab]

  public static let fixed: [Int: AppTab] = [0: .shelf, 2: .scan]
  public static let `default` = TabBarLayout(uncheckedOrder: [.shelf, .find, .scan, .activity, .you])

  private init(uncheckedOrder: [AppTab]) {
    order = uncheckedOrder
  }

  /// A layout with the movable tabs in `movable` order. Returns nil unless `movable` is exactly Find, Activity and
  /// You in some order.
  public init?(movable: [AppTab]) {
    guard movable.count == 3, Set(movable) == [.find, .activity, .you] else { return nil }
    order = [.shelf, movable[0], .scan, movable[1], movable[2]]
  }

  /// The tabs a collector can drag, in their current order.
  public var movable: [AppTab] { order.enumerated().filter { Self.fixed[$0.offset] == nil }.map(\.element) }

  /// Moves a movable tab to another movable position (0 to 2). Fixed tabs and out-of-range positions do nothing.
  public mutating func move(_ tab: AppTab, toMovablePosition position: Int) {
    var tabs = movable
    guard let from = tabs.firstIndex(of: tab), (0..<tabs.count).contains(position) else { return }
    tabs.insert(tabs.remove(at: from), at: position)
    self = TabBarLayout(movable: tabs) ?? self
  }

  public init(from decoder: any Decoder) throws {
    // A stored order that breaks the rules (a hand-edited or older setting, or a tab renamed since) falls back to
    // the default rather than failing: a setting must never stop the app from opening.
    let raw = (try? decoder.singleValueContainer().decode([String].self)) ?? []
    let order = raw.compactMap(AppTab.init(rawValue:))
    self =
      order.count == 5 && order[0] == .shelf && order[2] == .scan
      ? TabBarLayout(movable: [order[1], order[3], order[4]]) ?? .default
      : .default
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(order)
  }
}

public import Foundation

/// How the weekly nudge talks, or whether it does (board 21, F17): *Dry* by default.
public enum NudgeTone: String, Hashable, Sendable, Codable, CaseIterable {
  case dry, plain, off
}

/// The weekly nudge (F17, board 21): at most one a week, only about a named unfinished thing, and none when nothing
/// is unfinished. "Silence is the reward." It names one object, and how many more are like it; the words are the
/// screen's, in the tone the collector chose.
public struct WeeklyNudge: Hashable, Sendable {
  /// What's unfinished. Every object has a title (the rules refuse an empty one), so board 21's nameless photo is
  /// a capture not yet confirmed; more kinds join when there's something else to finish.
  public enum Kind: String, Hashable, Sendable {
    /// An object not yet confirmed or given details: "Saga #1 has been unverified for three weeks".
    case unconfirmed
  }

  public static let interval: TimeInterval = 7 * 86_400

  public let kind: Kind
  /// The object it names: the one waiting longest.
  public let objectID: ObjectID
  public let title: String
  /// How many objects are unfinished this way, that one included.
  public let count: Int
  /// When it's due: now, or a week after the last one.
  public let at: Date

  /// The nudge to send, if one is allowed: not with the tone off, not within a week of the last, and only when
  /// something is unfinished. Let-go objects are finished business, and wanted ones aren't the collector's yet.
  public static func next(shelf: Shelf, tone: NudgeTone, lastSent: Date?, now: Date) -> WeeklyNudge? {
    guard tone != .off else { return nil }
    let at = max(now, lastSent.map { $0 + interval } ?? now)
    let live = shelf.objects.values.filter { $0.letGo == nil && $0.ownership != .wanted }
      .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
    let unconfirmed = live.filter { $0.identity != .confirmed }
    if let first = unconfirmed.first {
      return WeeklyNudge(kind: .unconfirmed, objectID: first.id, title: first.title, count: unconfirmed.count, at: at)
    }
    return nil
  }
}

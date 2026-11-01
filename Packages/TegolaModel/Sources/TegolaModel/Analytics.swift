public import Foundation
public import TegolaCatalogue

/// A shape-only analytics event (F17, `05_Tagging and Metrics` trimmed to v1), kept on the phone. It records that
/// something happened and its shape, never what it was about: no title, no name, no note, no price can be expressed,
/// because a property is a flag, a bucket or a word from a closed set (CLAUDE.md: "an analytics event records shape,
/// never content").
public struct AnalyticsEvent: Hashable, Sendable, Codable {
  /// The v1 events. Purchases, unlocks, packs, share links and sync are later.
  public enum Name: String, Hashable, Sendable, Codable, CaseIterable {
    case firstOpen = "first_open"
    case sessionStarted = "session_started"
    case objectAdded = "object_added"
    case firstObjectAdded = "first_object_added"
    case objectOpened = "object_opened"
    case collectionCreated = "collection_created"
    case fieldFilled = "field_filled"
    case conditionChanged = "condition_changed"
    case searchPerformed = "search_performed"
    case importStarted = "import_started"
    case importCompleted = "import_completed"
    case importFailed = "import_failed"
    case reviewItemResolved = "review_item_resolved"
    case lookupRequested = "lookup_requested"
    case lookupResolved = "lookup_resolved"
    case lendCreated = "lend_created"
    case lendReturned = "lend_returned"
    case lendOverdueSeen = "lend_overdue_seen"
    case borrowedAdded = "borrowed_added"
    case wishAdded = "wish_added"
    case objectFlaggedSellable = "object_flagged_sellable"
    case exportCompleted = "export_completed"
    case tabBarEdited = "tab_bar_edited"
  }

  /// The properties an event may carry, by the taxonomy's names.
  public enum Key: String, Hashable, Sendable, Codable, CaseIterable, CodingKeyRepresentable {
    case type, source, fieldKind = "field_kind", resultBucket = "result_bucket", zeroResults = "zero_results"
    case rowsBucket = "rows_bucket", matchedPctBucket = "matched_pct_bucket", confidenceBucket = "confidence_bucket"
    case hasDueDate = "has_due_date", daysOutBucket = "days_out_bucket", hasCap = "has_cap", format
  }

  /// A property's value: never free text.
  public enum Value: Hashable, Sendable, Codable {
    case flag(Bool)
    case bucket(Bucket)
    /// A catalogue type: an id the app ships, not something the collector wrote.
    case type(TypeManifest.ID)
    /// A word from the app's own closed sets: an add's origin, a field kind, an export format.
    case word(Word)
  }

  /// Counts, rounded to a few ranges.
  public enum Bucket: String, Hashable, Sendable, Codable, CaseIterable {
    case none = "0", one = "1", few = "2-5", some = "6-20", many = "21-100", lots = "100+"

    public init(_ count: Int) {
      self =
        switch count {
        case ..<1: .none
        case 1: .one
        case 2...5: .few
        case 6...20: .some
        case 21...100: .many
        default: .lots
        }
    }
  }

  /// The words a property may hold.
  public enum Word: String, Hashable, Sendable, Codable, CaseIterable {
    // Where an object came from.
    case typed, captured, imported, firstPiece
    // Field kinds.
    case text, number, choice, yesNo, date, year, list, scale, set, other
    // Export formats.
    case csv, json, pdf
  }

  public let name: Name
  public let at: Date
  public let properties: [Key: Value]

  public init(_ name: Name, at: Date, _ properties: [Key: Value] = [:]) {
    self.name = name
    self.at = at
    self.properties = properties
  }
}

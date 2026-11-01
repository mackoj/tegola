public import TegolaCatalogue

/// What the shelf already has that looks like an object about to be added (F7, PD-044, PD-151): said unprompted
/// with every match, and asked about only when the collector probably owns it already. Nothing is ever merged.
public struct LookAlikes: Hashable, Sendable {
  /// The three answers to "you already own this" (F7).
  public enum Choice: Hashable, Sendable {
    /// Go to the one they have; nothing is added.
    case open(ObjectID)
    /// Another copy of it: one more on a count, or a row of its own.
    case anotherCopy(ObjectID)
    /// Not the same thing after all.
    case addAsNew
  }

  /// Owned and kept, same type, subtype and title: probably this very thing.
  public let owned: [ObjectID]
  /// Same type and title, another subtype: another print of it ("you have the PAL one").
  public let otherPrints: [ObjectID]
  /// On the wishlist: adding it is "it arrived" (D-13), which the screen offers instead.
  public let wanted: [ObjectID]
  /// Sharing a value the type file names as related: the same artist, publisher, designer or series.
  public let related: [ObjectID]

  /// At most this many related objects: the match sheet lists a few, not the shelf.
  public static let relatedLimit = 5

  public init(_ draft: ObjectDraft, shelf: Shelf, catalogue: Catalogue) {
    let title = Self.key(draft.values[.title])
    let sameTitle = shelf.objects.values
      .filter { $0.typeID == draft.type && $0.letGo == nil && !title.isEmpty && Self.key(.text($0.title)) == title }
      .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
    owned = sameTitle.filter { $0.ownership == .owned && $0.subtype == draft.subtype }.map(\.id)
    otherPrints = sameTitle.filter { $0.ownership == .owned && $0.subtype != draft.subtype }.map(\.id)
    wanted = sameTitle.filter { $0.ownership == .wanted }.map(\.id)

    let keys: [FieldKey] = (catalogue.manifest(draft.type)?.related ?? []).map {
      $0 == "subtitle" ? .subtitle : .field($0)
    }
    let seen = Set(sameTitle.map(\.id))
    related = Array(
      shelf.objects.values
        .filter { object in
          object.typeID == draft.type && object.letGo == nil && object.ownership == .owned && !seen.contains(object.id)
            && keys.contains { key in
              let value = Self.key(draft.values[key])
              return !value.isEmpty && value == Self.key(object.values[key])
            }
        }
        .sorted { (Self.key(.text($0.title)), $0.id) < (Self.key(.text($1.title)), $1.id) }
        .map(\.id)
        .prefix(Self.relatedLimit)
    )
  }

  /// It asks only when unsure: when the collector probably owns this already (F7).
  public var asks: Bool { !owned.isEmpty }

  public var choices: [Choice] {
    guard let first = owned.first else { return [.addAsNew] }
    return [.open(first), .anotherCopy(first), .addAsNew]
  }

  /// The write a choice makes, or nil for opening the one they have. Another copy of a count raises it (PD-020);
  /// another copy of anything else is its own object, in the same collection.
  public func command(
    for choice: Choice,
    adding draft: ObjectDraft,
    to collection: CollectionChoice,
    origin: AddOrigin,
    shelf: Shelf
  ) -> ShelfCommand? {
    switch choice {
    case .open:
      return nil
    case .anotherCopy(let id):
      guard let existing = shelf.objects[id] else { return .add(draft, to: collection, origin: origin) }
      if existing.bulk == .quantity { return .adjustQuantity(id, by: 1) }
      return .add(draft, to: .existing(existing.collectionID), origin: origin)
    case .addAsNew:
      return .add(draft, to: collection, origin: origin)
    }
  }

  /// Text compared without case, accents, width or extra spaces: "Tomb Raider " is "tomb raider".
  static func key(_ value: FieldValue?) -> String {
    guard case .text(let text) = value else { return "" }
    return normalize(text).lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
  }
}

/// The server's answer for one imported row (`POST /types/{type}/match`): a proposal at best, never a confirmation
/// (PD-042).
public enum MatchOutcome: Hashable, Sendable {
  /// One strong candidate: offered as enrichment, confirmed only by the collector.
  case matched(LookupCandidate)
  /// Two or three ("Which Tetris?"): the exceptions queue asks, one tap each.
  case ambiguous([LookupCandidate])
  /// None: the row stays on the shelf as written (49 Q2).
  case unknown

  /// Whether the exceptions queue holds it. Never a gate: **Keep as I wrote it** is the default (49 §04).
  public var asks: Bool { if case .ambiguous = self { true } else { false } }
}

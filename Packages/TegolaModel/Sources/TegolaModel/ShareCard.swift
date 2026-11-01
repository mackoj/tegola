public import TegolaCatalogue

/// A share card (F14, D-78): the image the share sheet sends. Sharing is one-sided in v1: a card is rendered on the
/// phone and sent, with no link behind it (PD-160).
///
/// What was paid is never on a card, of either kind, with money on or off (F14's *Done when*). The rule is
/// structural: no fact carries a money value, and the only money a card holds is the asking price the collector types
/// for *my copy*, and only with money on.
public struct ShareCard: Hashable, Sendable {
  public enum Kind: Hashable, Sendable {
    /// **Share the record**: the public facts about the thing: the spine's subtitle and year, and the fields a lookup
    /// fills.
    case record
    /// **Share my copy**: the record, plus every other field the collector filled, the condition and the photos.
    case myCopy
  }

  /// One line of the card: the field's label and its value.
  public struct Fact: Hashable, Sendable {
    public let key: FieldKey
    public let label: String
    public let value: FieldValue
  }

  public let kind: Kind
  public let typeID: TypeManifest.ID
  public let subtype: String?
  public let title: String
  /// In the type's order: the spine's subtitle and year, then the fields.
  public let facts: [Fact]
  /// The copy's photos, hero first; empty on a record.
  public let photos: [PhotoID]
  /// Only on *my copy*, only with money on.
  public let askingPrice: Money?

  public init(
    _ kind: Kind,
    object: ShelfObject,
    type: EffectiveType,
    manifest: TypeManifest,
    shelf: Shelf,
    money: MoneyVisibility,
    askingPrice: Money? = nil
  ) {
    self.kind = kind
    typeID = object.typeID
    subtype = object.subtype
    title = object.title
    var facts: [Fact] = []
    func add(_ key: FieldKey, _ label: String?) {
      // Promise 5 and F14: whatever the field, no money value goes on a card.
      guard let label, let value = object.values[key] else { return }
      if case .money = value { return }
      facts.append(Fact(key: key, label: label, value: value))
    }
    // The spine's public roles. Acquired, paid and value are the collector's own, never shared.
    add(.subtitle, manifest.spine.subtitle)
    add(.year, manifest.spine.year)
    let ladderAxes = Set(type.signatures.flatMap(\.axes))
    for effective in type.fields where !effective.isHidden && !ladderAxes.contains(effective.key) {
      let field = effective.field
      // The record's facts are the catalogue's: the fields a lookup fills (`auto`), the same for every copy. The rest
      // (a box's condition, sealed, framed, who signed this one, a play log) describe the collector's copy.
      guard field.kind != .money, kind == .myCopy || field.isAuto else { continue }
      add(.field(field.key), field.label)
    }
    if kind == .myCopy {
      // The condition: one grade per ladder part (PD-013's signature slot).
      // In the ladder's own order (media first), not alphabetical.
      var seen: Set<String> = []
      for axis in type.signatures.flatMap(\.axes) where seen.insert(axis).inserted {
        add(.axis(axis), type.field(axis)?.field.label ?? axis)
      }
    }
    self.facts = facts
    photos = kind == .myCopy ? shelf.photos(of: object.id).map(\.id) : []
    self.askingPrice = kind == .myCopy && money == .on ? askingPrice : nil
  }
}

/// The wishlist shared as cards (PD-071): what's wanted, never what's owned, and no money at all.
public struct WishlistCard: Hashable, Sendable {
  public struct Want: Hashable, Sendable {
    public let id: ObjectID
    public let typeID: TypeManifest.ID
    public let subtype: String?
    public let title: String
    public let year: Int?
    public let isGrail: Bool
  }

  /// The wanted objects, grails first, then by title.
  public let wants: [Want]

  public init(shelf: Shelf) {
    wants = shelf.objects.values
      .filter { $0.ownership == .wanted && $0.letGo == nil }
      .map { object in
        let year: Int? = if case .year(let y) = object.values[.year] { y } else { nil }
        return Want(
          id: object.id,
          typeID: object.typeID,
          subtype: object.subtype,
          title: object.title,
          year: year,
          isGrail: object.isGrail
        )
      }
      .sorted { ($0.isGrail ? 0 : 1, $0.title, $0.id) < ($1.isGrail ? 0 : 1, $1.title, $1.id) }
  }
}

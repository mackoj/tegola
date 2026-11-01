public import Foundation
public import TegolaCatalogue

/// A screen a feature asks for. Features send `.delegate(.open(Route))`; only the root pushes (PLAN §5). Deep links and
/// `--screen` map to the same values.
public enum Route: Hashable, Sendable {
  case collection(CollectionID)
  case object(ObjectID)
  case places
  case place(PlaceID)
  /// The signal feed: what needs attention (F15).
  case signals
  /// The review queue: what's left to confirm, with what lookups proposed (F8).
  case review
  case wishlist
}

/// Whether money shows (PD-080, PD-138: off by default). With it off, no read model carries a value, a paid figure or
/// a sell action; paid is still recorded (story 165, promise 5).
public enum MoneyVisibility: String, Hashable, Sendable, Codable {
  case on, off
}

/// How many objects something holds. A quantity object counts its copies; wanted, borrowed and let-go objects never
/// count (PD-061, PD-070, promise 4; D-43).
public func count(_ objects: some Sequence<ShelfObject>) -> Int {
  objects.reduce(0) { $0 + ($1.counts ? $1.quantity : 0) }
}

/// The Shelf home's numbers (F3): every one derived, never stored (PLAN §3.1).
public struct ShelfSummary: Hashable, Sendable {
  public struct CollectionLine: Hashable, Sendable, Identifiable {
    public let id: CollectionID
    public let name: String
    public let typeID: TypeManifest.ID?
    public let count: Int
    public let lent: Int
    public let sortKey: Int
  }

  /// Objects on the shelf.
  public let count: Int
  /// The shelf's value, per currency, only with money on (promise 5). Never added across currencies.
  public let value: [Money]?
  public let today: TodayStrip
  public let collections: [CollectionLine]
  /// Wanted objects: the wishlist, drawn as a dashed collection.
  public let wanted: Int
  /// The Places line shows once two places exist (F10).
  public let showsPlaces: Bool

  public init(
    shelf: Shelf,
    money: MoneyVisibility,
    now: Date,
    statuses: [ObjectID: ObjectStatus] = [:],
    signalled: Set<ObjectID> = []
  ) {
    let objects = Array(shelf.objects.values)
    count = TegolaModel.count(objects)
    let totals = Money.totals(
      objects.filter(\.counts).compactMap { if case .money(let m) = $0.values[.value] { m } else { nil } }
    )
    // With money on but nothing valued yet, there's no figure to show: the count stands instead.
    value = money == .on && !totals.isEmpty ? totals : nil
    today = TodayStrip(shelf: shelf, now: now, statuses: statuses, signalled: signalled)
    let lentOut = Set(shelf.loans.values.filter { $0.isOpen && $0.direction == .out }.map(\.objectID))
    collections = shelf.collections.values
      .map { collection in
        let members = objects.filter { $0.collectionID == collection.id }
        return CollectionLine(
          id: collection.id,
          name: collection.name,
          typeID: collection.typeID,
          count: TegolaModel.count(members),
          lent: members.filter { lentOut.contains($0.id) }.count,
          sortKey: collection.sortKey
        )
      }
      .sorted { ($0.sortKey, $0.name) < ($1.sortKey, $1.name) }
    wanted = objects.filter { $0.ownership == .wanted && $0.letGo == nil }.count
    showsPlaces = shelf.livePlaces.count >= 2
  }
}

/// The Today strip: only its non-empty lines, in a fixed order (F3, PD-140).
public struct TodayStrip: Hashable, Sendable {
  public enum Line: Hashable, Sendable {
    /// Objects waiting to be confirmed or given details.
    case toTidy(Int)
    /// Objects whose status is watch or act. One that's only overdue is on the overdue line instead; one with a clock
    /// signal too is here as well, so the count matches the feed it opens (D-59).
    case needAttention(Int)
    /// Loans past their due date.
    case overdue(Int)
  }

  public let lines: [Line]

  /// `signalled` are the objects with a clock signal that needs attention (`ShelfSignals.feed`).
  public init(
    shelf: Shelf,
    now: Date,
    statuses: [ObjectID: ObjectStatus],
    signalled: Set<ObjectID> = []
  ) {
    let live = shelf.objects.values.filter { $0.letGo == nil }
    let tidy = live.filter { $0.identity != .confirmed }.count
    let overdueObjects = Set(shelf.loans.values.filter { $0.isOverdue(at: now) }.map(\.objectID))
    let attention = live.filter {
      signalled.contains($0.id) || (statuses[$0.id]?.needsAttention == true && !overdueObjects.contains($0.id))
    }
    .count
    let overdue = shelf.loans.values.filter { $0.isOverdue(at: now) }.count
    lines = [.toTidy(tidy), .needAttention(attention), .overdue(overdue)].filter { line in
      switch line {
      case .toTidy(let n), .needAttention(let n), .overdue(let n): n > 0
      }
    }
  }
}

/// A collection's mono meta line (`128 RELEASES · 2 LENT`): the numbers and the type's noun; the feature words it.
public struct CollectionMeta: Hashable, Sendable {
  public let count: Int
  public let lent: Int
  /// The type's noun for the count (singular for one), or nil for a mixed collection.
  public let noun: String?

  public init(collection: ShelfCollection, shelf: Shelf, catalogue: Catalogue) {
    let members = shelf.objects.values.filter { $0.collectionID == collection.id }
    count = TegolaModel.count(members)
    let ids = Set(members.map(\.id))
    lent = shelf.loans.values.filter { $0.isOpen && $0.direction == .out && ids.contains($0.objectID) }.count
    let total = count
    noun = collection.typeID.flatMap { catalogue.manifest($0)?.name.noun(for: total) }
  }
}

/// The object screen's seven slots, in their fixed order (PD-013): what each one holds for one object.
public struct ObjectSlots: Hashable, Sendable {
  public enum Slot: String, CaseIterable, Hashable, Sendable {
    case hero, spine, status, signature, fields, actions, history
  }

  /// A spine line: the type's label for the role, and the value.
  public struct SpineLine: Hashable, Sendable {
    public let key: FieldKey
    public let label: String
    public let value: FieldValue
  }

  /// A field with a value, in the order the edit form shows it.
  public struct FieldLine: Hashable, Sendable {
    public let field: TypeManifest.Field
    public let value: FieldValue
    public let isAuto: Bool
  }

  public enum Action: String, CaseIterable, Hashable, Sendable {
    case edit, photo, lend, returnLoan, mightLetGo, letGo, promote, setOwned
    /// Someone else's object: say whose it is, then give it back (PD-061).
    case markBorrowed, giveBack
  }

  /// The order is the product's, never the type's.
  public static let order = Slot.allCases

  public let spine: [SpineLine]
  public let fields: [FieldLine]
  /// The ladder's axes and their grades, when the type has a ladder.
  public let ladder: [(key: String, label: String, grade: String?)]
  /// The set's slots and which are present, when the type has a set signature.
  public let set: (slots: [String], present: Set<String>)?
  public let actions: [Action]

  public init(object: ShelfObject, type: EffectiveType, manifest: TypeManifest, shelf: Shelf, money: MoneyVisibility) {
    let labels = manifest.spine
    let roles: [(FieldKey, String?)] = [
      (.subtitle, labels.subtitle), (.year, labels.year), (.acquired, labels.acquired), (.paid, labels.paid),
      (.value, labels.value),
    ]
    spine = roles.compactMap { key, label in
      // Promise 5: with money off, no paid figure and no value on any screen.
      guard money == .on || !key.isMoney, let label, let value = object.values[key] else { return nil }
      return SpineLine(key: key, label: label, value: value)
    }
    let ladderAxes = Set(type.signatures.first { $0.renderer == SignatureRenderer.ladder.rawValue }?.axes ?? [])
    fields = type.fields.compactMap { effective in
      guard !effective.isHidden, !ladderAxes.contains(effective.key),
        let value = object.values[.field(effective.key)]
      else { return nil }
      return FieldLine(field: effective.field, value: value, isAuto: object.auto.contains(.field(effective.key)))
    }
    if let signature = type.signatures.first(where: { $0.renderer == SignatureRenderer.ladder.rawValue }) {
      ladder = signature.axes.map { axis in
        let grade: String? = if case .text(let g) = object.values[.axis(axis)] { g } else { nil }
        return (axis, type.field(axis)?.field.label ?? axis, grade)
      }
    } else {
      ladder = []
    }
    if let signature = type.signatures.first(where: { $0.renderer == SignatureRenderer.set.rawValue }),
      let binds = signature.binds, let field = type.field(binds)
    {
      let present: Set<String> = if case .options(let o) = object.values[.field(binds)] { Set(o) } else { [] }
      set = (field.field.options, present)
    } else {
      set = nil
    }
    let onLoan = shelf.openLoan(on: object.id)
    var actions: [Action] = [.edit, .photo]
    if object.ownership == .owned && object.letGo == nil {
      if object.bulk == .rows {
        actions.append(onLoan == nil ? .lend : .returnLoan)
      } else {
        actions.append(.promote)
      }
      actions += [.mightLetGo, .letGo]
    }
    if object.ownership == .wanted { actions.append(.setOwned) }
    if object.ownership == .borrowed && object.letGo == nil {
      actions.append(onLoan?.direction == .in ? .giveBack : .markBorrowed)
    }
    self.actions = actions
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.spine == rhs.spine && lhs.fields == rhs.fields && lhs.actions == rhs.actions
      && lhs.ladder.map(\.key) == rhs.ladder.map(\.key) && lhs.ladder.map(\.grade) == rhs.ladder.map(\.grade)
      && lhs.set?.slots == rhs.set?.slots && lhs.set?.present == rhs.set?.present
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(spine)
    hasher.combine(fields)
    hasher.combine(actions)
  }
}

extension TypeManifest.Names {
  /// The type's own word for a count of objects: "1 release", "4 releases". Type files are data in English; the
  /// numbers around them are localized by the screen.
  public func noun(for count: Int) -> String {
    count == 1 ? singular : plural
  }
}

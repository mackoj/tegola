public import Foundation
public import TegolaCatalogue
public import TegolaModel

/// A seeded generator, so a failing sequence is the same sequence on the next run (SplitMix64).
public struct SeededGenerator: RandomNumberGenerator {
  var state: UInt64

  public init(seed: UInt64) { state = seed }

  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

/// Random commands over the current shelf: some valid, some the rules refuse. Values come from small pools, so edits,
/// lookups and confirmations collide often.
public struct CommandGenerator {
  public let type: TypeManifest.ID
  let catalogue: Catalogue
  var random: SeededGenerator
  /// Every acquired date any command supplied: promise 7 says the app never invents one.
  public private(set) var suppliedAcquired: Set<Date> = []

  static let titles = ["Radiant Silvergun", "Kid A", "Brass", "Meeples", "Doom"]
  static let notes = ["From a car boot", "Gift", "Box dented"]
  static let acquired = [Date(timeIntervalSince1970: 1_500_000_000), Date(timeIntervalSince1970: 1_600_000_000)]

  public init(type: TypeManifest.ID, catalogue: Catalogue, seed: UInt64) {
    self.type = type
    self.catalogue = catalogue
    self.random = SeededGenerator(seed: seed)
  }

  mutating func pick<T>(_ values: [T]) -> T { values.randomElement(using: &random)! }
  mutating func chance(_ percent: Int) -> Bool { Int.random(in: 0..<100, using: &random) < percent }

  /// A value the type accepts for one of its own text or choice fields, when it has one.
  func textField(_ shelf: Shelf) -> FieldKey? {
    guard let effective = try? catalogue.resolve(type, subtype: nil) else { return nil }
    return effective.visibleFields.first { $0.field.kind == .text }.map { .field($0.key) }
  }

  /// `acquired` is recorded as supplied only when the collector supplies it; a lookup's offer of one must be dropped.
  mutating func values(_ shelf: Shelf, allowAcquired: Bool, recordAcquired: Bool = true) -> [FieldKey: FieldValue] {
    var values: [FieldKey: FieldValue] = [:]
    if chance(50) { values[.notes] = .text(pick(Self.notes)) }
    if chance(40) { values[.year] = .year(pick([1994, 1998, 2001])) }
    if let key = textField(shelf), chance(50) { values[key] = .text(pick(["A", "B", "C"])) }
    // Money, so promise 5 has something to hide: paid and value, in two currencies.
    if allowAcquired && chance(30) {
      let currency = Currency(pick(["EUR", "JPY"]))!
      values[pick([FieldKey.paid, .value])] = .money(
        Money(minorUnits: Int.random(in: 100...90_000, using: &random), currency: currency)
      )
    }
    if allowAcquired && chance(30) {
      let date = pick(Self.acquired)
      if recordAcquired { suppliedAcquired.insert(date) }
      values[.acquired] = .date(date)
    }
    return values
  }

  /// The next command, and who sends it.
  public mutating func next(on shelf: Shelf) -> (ShelfCommand, ShelfEvent.Source) {
    let objects = shelf.objects.keys.sorted()
    let loans = shelf.loans.values.filter(\.isOpen).map(\.id).sorted()
    let collection = shelf.collections.values.first { $0.typeID == type }
    guard let object = objects.isEmpty ? nil : pick(objects), chance(85) else {
      // Half the objects take a subtype, so presets, hidden fields and additions are exercised too.
      let subtypes = catalogue.manifest(type)?.subtypes.map(\.key) ?? []
      let subtype = subtypes.isEmpty || chance(50) ? nil : pick(subtypes)
      var draft = ObjectDraft(type: type, subtype: subtype, values: values(shelf, allowAcquired: true))
      draft.values[.title] = .text(pick(Self.titles))
      draft.ownership = pick([.owned, .owned, .owned, .wanted])
      if draft.ownership == .wanted { draft.values[.acquired] = nil }
      if chance(10) { draft.ownership = .borrowed }
      if type == "thing" && chance(50) {
        draft.bulk = .quantity
        draft.quantity = Int.random(in: 1...4, using: &random)
      }
      let origin = pick([AddOrigin.typed, .captured, .imported])
      let source: ShelfEvent.Source = origin == .captured ? .capture : origin == .imported ? .import : .collector
      return (.add(draft, to: collection.map { .existing($0.id) } ?? .new(name: "Mine"), origin: origin), source)
    }
    switch Int.random(in: 0..<15, using: &random) {
    case 0: return (.confirm([object]), pick([.collector, .lookup]))
    case 1:
      let edits = values(shelf, allowAcquired: true).mapValues { Optional($0) }
      return (.edit(object, values: edits), pick([.collector, .collector, .lookup]))
    case 2, 3:
      // A lookup offers values for any key, typed or not; it must only fill the empty and the AUTO ones.
      var offered = values(shelf, allowAcquired: true, recordAcquired: false)
      offered[.title] = .text(pick(Self.titles))
      return (.applyLookup(object, values: offered), .lookup)
    case 4: return (.setPlace([object], PlacePath(typed: pick(["Office › Shelf 2", "Attic", "Office"]))), .collector)
    case 5: return (.lend(object, to: .new(name: pick(["Max", "Léa"])), due: nil, note: ""), .collector)
    case 6: return (loans.isEmpty ? .giveBack(object) : .returnLoan(pick(loans), condition: nil), .collector)
    case 7: return (.markBorrowed(object, from: .new(name: "Léa")), .collector)
    case 13: return (.edit(object, values: [pick([FieldKey.year, .notes]): nil]), .collector)
    case 8: return (.letGo(object, pick([.gifted, .lost, .sold(price: nil)])), .collector)
    case 9: return (.promote(object), .collector)
    case 10: return (.adjustQuantity(object, by: pick([-1, 1, 2])), .collector)
    case 11: return (.setGrail(object, chance(50)), .collector)
    case 12: return (.setOwned(object), .collector)
    default: return (.logEvent(object, kind: "cleaned", note: ""), .collector)
    }
  }
}

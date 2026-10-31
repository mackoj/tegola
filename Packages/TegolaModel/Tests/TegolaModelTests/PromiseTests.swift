import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

/// A seeded generator, so a failing sequence is the same sequence on the next run (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
  var state: UInt64

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

/// Random commands over the current shelf: some valid, some the rules refuse. Values come from small pools, so edits,
/// lookups and confirmations collide often.
struct CommandGenerator {
  let type: TypeManifest.ID
  var random: SeededGenerator
  /// Every acquired date any command supplied: promise 7 says the app never invents one.
  var suppliedAcquired: Set<Date> = []

  static let titles = ["Radiant Silvergun", "Kid A", "Brass", "Meeples", "Doom"]
  static let notes = ["From a car boot", "Gift", "Box dented"]
  static let acquired = [Date(timeIntervalSince1970: 1_500_000_000), Date(timeIntervalSince1970: 1_600_000_000)]

  init(type: TypeManifest.ID, seed: UInt64) {
    self.type = type
    self.random = SeededGenerator(state: seed)
  }

  mutating func pick<T>(_ values: [T]) -> T { values.randomElement(using: &random)! }
  mutating func chance(_ percent: Int) -> Bool { Int.random(in: 0..<100, using: &random) < percent }

  /// A value the type accepts for one of its own text or choice fields, when it has one.
  func textField(_ shelf: Shelf) -> FieldKey? {
    guard let effective = try? Harness.catalogue.resolve(type, subtype: nil) else { return nil }
    return effective.visibleFields.first { $0.field.kind == .text }.map { .field($0.key) }
  }

  mutating func values(_ shelf: Shelf, allowAcquired: Bool) -> [FieldKey: FieldValue] {
    var values: [FieldKey: FieldValue] = [:]
    if chance(50) { values[.notes] = .text(pick(Self.notes)) }
    if chance(40) { values[.year] = .year(pick([1994, 1998, 2001])) }
    if let key = textField(shelf), chance(50) { values[key] = .text(pick(["A", "B", "C"])) }
    if allowAcquired && chance(30) {
      let date = pick(Self.acquired)
      suppliedAcquired.insert(date)
      values[.acquired] = .date(date)
    }
    return values
  }

  mutating func next(on shelf: Shelf) -> (ShelfCommand, ShelfEvent.Source) {
    let objects = shelf.objects.keys.sorted()
    let loans = shelf.loans.values.filter(\.isOpen).map(\.id).sorted()
    let collection = shelf.collections.values.first { $0.typeID == type }
    guard let object = objects.isEmpty ? nil : pick(objects), chance(85) else {
      var draft = ObjectDraft(type: type, values: values(shelf, allowAcquired: true))
      draft.values[.title] = .text(pick(Self.titles))
      draft.ownership = pick([.owned, .owned, .owned, .wanted])
      if draft.ownership == .wanted { draft.values[.acquired] = nil }
      if type == "thing" && chance(50) {
        draft.bulk = .quantity
        draft.quantity = Int.random(in: 1...4, using: &random)
      }
      let origin = pick([AddOrigin.typed, .captured, .imported])
      let source: ShelfEvent.Source = origin == .captured ? .capture : origin == .imported ? .import : .collector
      return (.add(draft, to: collection.map { .existing($0.id) } ?? .new(name: "Mine"), origin: origin), source)
    }
    switch Int.random(in: 0..<14, using: &random) {
    case 0: return (.confirm([object]), pick([.collector, .lookup]))
    case 1:
      let edits = values(shelf, allowAcquired: true).mapValues { Optional($0) }
      return (.edit(object, values: edits), pick([.collector, .collector, .lookup]))
    case 2, 3:
      // A lookup offers values for any key, typed or not; it must only fill the empty and the AUTO ones.
      var offered = values(shelf, allowAcquired: false)
      offered[.title] = .text(pick(Self.titles))
      return (.applyLookup(object, values: offered), .lookup)
    case 4: return (.setPlace([object], PlacePath(typed: pick(["Office › Shelf 2", "Attic", "Office"]))), .collector)
    case 5: return (.lend(object, to: .new(name: pick(["Max", "Léa"])), due: nil, note: ""), .collector)
    case 6: return (loans.isEmpty ? .giveBack(object) : .returnLoan(pick(loans), condition: nil), .collector)
    case 7: return (.markBorrowed(object, from: .new(name: "Léa")), .collector)
    case 8: return (.letGo(object, pick([.gifted, .lost, .sold(price: nil)])), .collector)
    case 9: return (.promote(object), .collector)
    case 10: return (.adjustQuantity(object, by: pick([-1, 1, 2])), .collector)
    case 11: return (.setGrail(object, chance(50)), .collector)
    case 12: return (.setOwned(object), .collector)
    default: return (.logEvent(object, kind: "cleaned", note: ""), .collector)
    }
  }
}

/// The product's promises, as properties over random command sequences, once per v1 type (PLAN §3.4). Promises 4 and
/// 5 are about counts and screen state, which arrive with the Shelf summary in M3.
@Suite struct PromiseTests {
  static let sequences = 40
  static let steps = 60

  @Test(arguments: Catalogue.enabledInV1)
  func promisesHoldOverRandomCommands(_ type: TypeManifest.ID) throws {
    for seed in 1...UInt64(Self.sequences) {
      var harness = Harness()
      var generator = CommandGenerator(type: type, seed: seed &* 7919 &+ UInt64(type.rawValue.count))
      for _ in 0..<Self.steps {
        let before = harness.shelf
        let logBefore = harness.log
        let (command, source) = generator.next(on: harness.shelf)
        let refused: Bool
        do {
          try harness.perform(command, as: source)
          refused = false
        } catch {
          refused = true
          #expect(harness.shelf == before, "a refused command changed the shelf")
        }
        let after = harness.shelf
        let context = "seed \(seed), \(command)"

        // 1. No command but the collector's own edit changes a value the collector typed (PD-045, PD-047).
        let isCollectorEdit = if case .edit = command { source == .collector } else { false }
        if !isCollectorEdit {
          for (id, old) in before.objects {
            for (key, value) in old.values where !old.auto.contains(key) {
              #expect(after.objects[id]?.values[key] == value, "typed \(key) changed: \(context)")
            }
          }
        }
        // 2. No command merges or removes an object (PD-151).
        #expect(Set(before.objects.keys).isSubset(of: after.objects.keys), "an object went: \(context)")
        // 3. History only grows: the old log is a prefix of the new one (PD-051).
        #expect(Array(harness.log.prefix(logBefore.count)) == logBefore, "history changed: \(context)")
        // 6. A count is never lent (PD-020, PD-121).
        if case .lend(let id, _, _, _) = command, before.objects[id]?.bulk == .quantity {
          #expect(refused, "a count was lent: \(context)")
        }
        // 7. The app never writes `acquired` (PD-165).
        for object in after.objects.values {
          if let acquired = object.acquiredAt {
            #expect(generator.suppliedAcquired.contains(acquired), "acquired invented: \(context)")
          }
        }
        // 8. Nothing is confirmed without a collector action (PD-042).
        for (id, object) in after.objects where object.identity == .confirmed {
          let wasConfirmed = before.objects[id]?.identity == .confirmed
          let confirmedByCollector: Bool =
            switch command {
            case .confirm: source == .collector
            case .add(_, _, let origin): origin != .captured
            case .promote: true
            default: false
            }
          #expect(wasConfirmed || confirmedByCollector, "confirmed without the collector: \(context)")
        }
      }
      // The log rebuilds the shelf it produced: the projection is derived, never the source (D-17).
      #expect(apply(harness.log, to: Shelf()) == harness.shelf, "replay differs: seed \(seed)")
    }
  }
}

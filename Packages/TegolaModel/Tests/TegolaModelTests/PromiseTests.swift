import Foundation
import TegolaCatalogue
import TegolaModelTesting
import Testing

@testable import TegolaModel

/// The product's promises, as properties over random command sequences, once per v1 type (PLAN §3.4). Promises 4 and 5
/// are checked on the read models screens draw from (`ShelfSummary`, `ObjectSlots`).
@Suite struct PromiseTests {
  static let sequences = 40
  static let steps = 60

  @Test(arguments: Catalogue.enabledInV1)
  func promisesHoldOverRandomCommands(_ type: TypeManifest.ID) throws {
    for seed in 1...UInt64(Self.sequences) {
      var harness = Harness()
      var generator = CommandGenerator(
        type: type,
        catalogue: Harness.catalogue,
        seed: seed &* 7919 &+ UInt64(type.rawValue.count)
      )
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
        // The one way out: the collector undoes an import, and only the rows nobody touched since go (PD-047, D-12).
        let undone = Set(before.objects.keys).subtracting(after.objects.keys)
        if case .undoBatch(let batchID) = command, source == .collector {
          for id in undone {
            #expect(before.objects[id]?.imported == ImportMark(batchID: batchID, touched: false), "undo: \(context)")
          }
        } else {
          // 2. No command merges or removes an object (PD-151).
          #expect(undone.isEmpty, "an object went: \(context)")
        }
        if !isCollectorEdit {
          for (id, old) in before.objects where !undone.contains(id) {
            // Typed and cleared keys alike: a cleared key stays empty.
            for key in old.typed {
              #expect(after.objects[id]?.values[key] == old.values[key], "typed \(key) changed: \(context)")
            }
          }
        }
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
        // 4. Wanted, borrowed and let-go objects never count (PD-061, PD-070): adding one leaves the count alone, and
        // the count is the copies of what's owned and kept.
        let summary = ShelfSummary(shelf: after, money: .off, now: harness.clock)
        let owned = after.objects.values.filter { $0.ownership == .owned && $0.letGo == nil }
        #expect(summary.count == owned.reduce(0) { $0 + $1.quantity }, "count: \(context)")
        if case .add(let draft, _, _) = command, draft.ownership != .owned {
          #expect(summary.count == ShelfSummary(shelf: before, money: .off, now: harness.clock).count, "\(context)")
        }
        #expect(summary.collections.reduce(0) { $0 + $1.count } == summary.count, "collections: \(context)")
        // 5. With money off, no read model carries a value or a paid figure (PD-080, PD-063).
        #expect(summary.value == nil, "value with money off: \(context)")
        for object in after.objects.values {
          let manifest = Harness.catalogue.manifest(object.typeID)!
          let effective = try Harness.catalogue.resolve(object.typeID, subtype: object.subtype)
          let slots = ObjectSlots(object: object, type: effective, manifest: manifest, shelf: after, money: .off)
          #expect(!slots.spine.contains { $0.key.isMoney }, "money on the object screen: \(context)")
        }
        // 8. Nothing is confirmed without a collector action (PD-042).
        for (id, object) in after.objects where object.identity == .confirmed {
          let wasConfirmed = before.objects[id]?.identity == .confirmed
          let confirmedByCollector: Bool =
            switch command {
            case .confirm: source == .collector
            case .add(_, _, let origin): origin != .captured && source != .capture && source != .lookup
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

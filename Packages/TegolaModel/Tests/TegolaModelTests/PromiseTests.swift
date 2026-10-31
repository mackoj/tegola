import Foundation
import TegolaCatalogue
import TegolaModelTesting
import Testing

@testable import TegolaModel

/// The product's promises, as properties over random command sequences, once per v1 type (PLAN §3.4). Promises 4 and
/// 5 are about counts and screen state, which arrive with the Shelf summary in M3.
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
        if !isCollectorEdit {
          for (id, old) in before.objects {
            // Typed and cleared keys alike: a cleared key stays empty.
            for key in old.typed {
              #expect(after.objects[id]?.values[key] == old.values[key], "typed \(key) changed: \(context)")
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

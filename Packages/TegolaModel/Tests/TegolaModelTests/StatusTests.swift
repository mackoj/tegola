import Foundation
import TegolaCatalogue
import TegolaModelTesting
import Testing

@testable import TegolaModel

/// Status derivation (D-15, D-59) and the shelf's signals.
@Suite struct StatusTests {
  static func signals(_ harness: Harness, optedIn: Set<String> = []) -> ShelfSignals {
    ShelfSignals(
      shelf: harness.shelf,
      catalogue: Harness.catalogue,
      now: harness.clock,
      calendar: .utc,
      optedIn: optedIn
    )
  }

  @Test func aDueCartridgeIsWatchAndNeedsAttention() throws {
    var harness = Harness()
    let due = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    let young = try SaveBatteryClockTests.cartridge(&harness, year: 2015)
    let plain = try harness.add(subtype: "saturn", values: [.field("region"): .text("PAL"), .year: .year(1996)])
    let shelf = Self.signals(harness)
    #expect(shelf.statuses[due] == .watch)
    #expect(shelf.statuses[young] == .good)
    #expect(shelf.statuses[plain] == .fine)
    #expect(shelf.feed.map(\.object) == [due])
    let today = TodayStrip(shelf: harness.shelf, now: harness.clock, statuses: shelf.statuses)
    #expect(today.lines == [.needAttention(1)])
  }

  @Test func theFeedPutsActBeforeWatch() throws {
    var harness = Harness()
    let watch = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    let act = try SaveBatteryClockTests.cartridge(&harness, year: 1980)
    #expect(Self.signals(harness).feed.map(\.object) == [act, watch])
  }

  @Test func letGoIsGoneAndWantedOrBorrowedHaveNoSignals() throws {
    var harness = Harness()
    let gone = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    try harness.perform(.letGo(gone, .gifted))
    let wanted = try harness.add(
      subtype: "game-boy",
      values: [.field("region"): .text("PAL"), .year: .year(1994)],
      ownership: .wanted
    )
    let shelf = Self.signals(harness)
    #expect(shelf.statuses[gone] == .gone)
    #expect(shelf.statuses[wanted] == .fine)
    #expect(shelf.signals.isEmpty)
  }

  /// An overdue loan is *act* on its object, but the Today strip counts it once, on its own line.
  @Test func anOverdueLoanIsActAndCountedOnce() throws {
    var harness = Harness()
    let id = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    try harness.perform(.lend(id, to: .new(name: "Dara"), due: harness.clock + 60, note: ""))
    harness.clock += 3_600
    let shelf = Self.signals(harness)
    #expect(shelf.statuses[id] == .act)
    #expect(TodayStrip(shelf: harness.shelf, now: harness.clock, statuses: shelf.statuses).lines == [.overdue(1)])
  }

  /// The state the clocks read is kept by `apply`, so a replayed log reads the same.
  @Test func aSwapIsKeptOnTheObject() throws {
    var harness = Harness()
    let id = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    try harness.perform(.logEvent(id, kind: ShelfEvent.Kind.servicedKind, note: "Battery swap"))
    #expect(harness.shelf.objects[id]?.signalState?.lastServiced == harness.log.last?.at)
    #expect(apply(harness.log, to: Shelf()) == harness.shelf)
    #expect(Self.signals(harness).statuses[id] == .good)
  }

  /// Wanted, borrowed and let-go objects never need attention, over random commands on every v1 type.
  @Test(arguments: Catalogue.enabledInV1)
  func onlyWhatsOwnedAndKeptNeedsAttention(_ type: TypeManifest.ID) throws {
    for seed in 1...UInt64(20) {
      var harness = Harness()
      var generator = CommandGenerator(type: type, catalogue: Harness.catalogue, seed: seed &* 104_729)
      for _ in 0..<40 {
        let (command, source) = generator.next(on: harness.shelf)
        _ = try? harness.perform(command, as: source)
      }
      // Far enough ahead that every clock with something to read has moved on.
      let later = harness.clock + 40 * 365 * 86_400
      let shelf = ShelfSignals(shelf: harness.shelf, catalogue: Harness.catalogue, now: later, calendar: .utc)
      for object in harness.shelf.objects.values where !object.counts {
        #expect(shelf.statuses[object.id]?.needsAttention == false, "seed \(seed): \(object.ownership)")
        #expect(shelf.signals[object.id] == nil)
      }
    }
  }
}

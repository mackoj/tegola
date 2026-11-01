import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

/// Dismissing a signal (F15, risk R2, D-60).
@Suite struct DismissalTests {
  static func showing(_ harness: Harness, _ id: ObjectID) throws -> [Signal] {
    try SaveBatteryClockTests.signals(harness, id)
  }

  @Test func aDismissedSignalStopsShowingAndIsLoggedWithItsParameters() throws {
    var harness = Harness()
    let id = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    let signal = try #require(try Self.showing(harness, id).first)
    let events = try harness.perform(.dismissSignal(id, signal))
    #expect(
      events.map(\.kind) == [
        .signalDismissed(
          id,
          SignalDismissal(
            clock: "saveBattery",
            status: .watch,
            parameters: ClockLibrary.definition("saveBattery")!.parameters
          )
        )
      ]
    )
    #expect(try Self.showing(harness, id).isEmpty)
    let shelf = ShelfSignals(shelf: harness.shelf, catalogue: Harness.catalogue, now: harness.clock, calendar: .utc)
    #expect(shelf.statuses[id] == .fine)
    #expect(apply(harness.log, to: Shelf()) == harness.shelf)
  }

  @Test func itShowsAgainOnceTheReadingGetsWorse() throws {
    var harness = Harness()
    let id = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    try harness.perform(.dismissSignal(id, try #require(try Self.showing(harness, id).first)))
    harness.clock = Calendar.utc.date(from: DateComponents(year: 2030, month: 1, day: 1))!
    #expect(try Self.showing(harness, id).map(\.status) == [.act])
  }

  @Test func newEvidenceEndsADismissal() throws {
    var harness = Harness()
    let id = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    try harness.perform(.dismissSignal(id, try #require(try Self.showing(harness, id).first)))
    try harness.perform(.edit(id, values: [.year: .year(1995)]))
    #expect(try Self.showing(harness, id).map(\.status) == [.watch])
  }

  @Test func onlyASignalThatNeedsAttentionFromAClockItRunsCanBeDismissed() throws {
    var harness = Harness()
    let young = try SaveBatteryClockTests.cartridge(&harness, year: 2015)
    let good = try #require(try Self.showing(harness, young).first)
    #expect(throws: ShelfRuleViolation.notDismissable) { try harness.perform(.dismissSignal(young, good)) }
    let disc = try harness.add(subtype: "saturn", values: [.field("region"): .text("PAL"), .year: .year(1995)])
    let rot = Signal(
      clock: "discRot",
      status: .watch,
      reason: .checked(since: 1995, wasChecked: false, everyYears: 5),
      changesAt: nil
    )
    #expect(throws: ShelfRuleViolation.notDismissable) { try harness.perform(.dismissSignal(disc, rot)) }
    let wanted = try harness.add(
      subtype: "game-boy",
      values: [.field("region"): .text("PAL"), .year: .year(1994)],
      ownership: .wanted
    )
    let battery = Signal(
      clock: "saveBattery",
      status: .watch,
      reason: .battery(since: 1994, swapped: false, lastsYears: 25...35),
      changesAt: nil
    )
    #expect(throws: ShelfRuleViolation.notDismissable) { try harness.perform(.dismissSignal(wanted, battery)) }
  }
}

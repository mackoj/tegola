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

  /// Review of M4, finding 1: `plan` checks the reading itself, so a stale or invented signal is refused.
  @Test func aSignalThatIsntShowingIsRefused() throws {
    var harness = Harness()
    let id = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    // The battery reads watch, not act.
    let wrong = Signal(
      clock: "saveBattery",
      status: .act,
      reason: .battery(since: 1994, swapped: false, lastsYears: 25...35),
      changesAt: nil
    )
    #expect(throws: ShelfRuleViolation.notDismissable) { try harness.perform(.dismissSignal(id, wrong)) }
    // Every game names codeExpiry, but this one has no code date: nothing to dismiss.
    let code = Signal(clock: "codeExpiry", status: .watch, reason: .codeExpires(harness.clock), changesAt: nil)
    #expect(throws: ShelfRuleViolation.notDismissable) { try harness.perform(.dismissSignal(id, code)) }
  }

  /// An opt-in clock's signal can be dismissed: it was only seen because the collector turned it on.
  @Test func anOptInSignalCanBeDismissed() throws {
    var harness = Harness()
    let id = try SaveBatteryClockTests.cartridge(&harness, year: nil)
    try harness.perform(.edit(id, values: [.field("playStatus"): .text("Playing")]))
    harness.clock += 400 * 86_400
    let since = try #require(harness.shelf.objects[id]?.signalState?.playingSince)
    let signal = Signal(clock: "unfinished", status: .watch, reason: .unfinished(since: since), changesAt: nil)
    try harness.perform(.dismissSignal(id, signal))
    #expect(harness.shelf.objects[id]?.signalState?.dismissed["unfinished"] == .watch)
  }

  /// Review of M4, finding 2: new evidence for one clock lifts only that clock's dismissal.
  @Test func evidenceForOneClockLeavesAnothersDismissal() throws {
    var harness = Harness()
    let expires = harness.clock + 30 * 86_400
    let id = try SaveBatteryClockTests.cartridge(&harness, year: 1994, values: [.field("codeExpires"): .date(expires)])
    let showing = try Self.showing(harness, id)
    #expect(Set(showing.map(\.clock)) == ["codeExpiry", "saveBattery"])
    let code = try #require(showing.first { $0.clock == "codeExpiry" })
    try harness.perform(.dismissSignal(id, code))
    try harness.perform(.logEvent(id, kind: ShelfEvent.Kind.servicedKind, note: ""))
    #expect(try Self.showing(harness, id).map(\.clock) == ["saveBattery"])
    try harness.perform(.edit(id, values: [.field("playStatus"): .text("Finished")]))
    #expect(try Self.showing(harness, id).map(\.clock) == ["saveBattery"])
    try harness.perform(.edit(id, values: [.field("codeExpires"): .date(expires + 86_400)]))
    #expect(Set(try Self.showing(harness, id).map(\.clock)) == ["codeExpiry", "saveBattery"])
  }

  /// Review of M4, finding 5: a dismissed signal still gets a notification for the day it gets worse.
  @Test func aDismissedSignalIsNotifiedWhenItWouldShowAgain() throws {
    var harness = Harness()
    let id = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    try harness.perform(.dismissSignal(id, try #require(try Self.showing(harness, id).first)))
    let object = try #require(harness.shelf.objects[id])
    let type = try Harness.catalogue.resolve(object.typeID, subtype: object.subtype)
    let upcoming = upcomingChanges(for: object, type: type, now: harness.clock, calendar: .utc)
    #expect(upcoming.map(\.clock) == ["saveBattery"])
    #expect(upcoming.first?.changesAt == Calendar.utc.date(from: DateComponents(year: 2029, month: 1, day: 1)))
  }
}

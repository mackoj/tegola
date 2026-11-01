import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

extension Calendar {
  /// The tests' calendar: Gregorian in UTC, so a year boundary is the same everywhere.
  static let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()
}

/// The clocks over a real object, through `plan` and `apply`. `Harness.start` is in January 2027.
@Suite struct SaveBatteryClockTests {
  /// A Game Boy cartridge released in `year`.
  static func cartridge(_ harness: inout Harness, year: Int?, values: [FieldKey: FieldValue] = [:]) throws -> ObjectID {
    var values = values
    values[.field("region")] = .text("PAL")
    if let year { values[.year] = .year(year) }
    return try harness.add(subtype: "game-boy", values: values)
  }

  static func signals(_ harness: Harness, _ id: ObjectID) throws -> [Signal] {
    let object = try #require(harness.shelf.objects[id])
    let type = try Harness.catalogue.resolve(object.typeID, subtype: object.subtype)
    return TegolaModel.signals(
      for: object,
      type: type,
      now: harness.clock,
      calendar: .utc
    )
  }

  /// F15's done-when, first half: a battery that's due shows watch, with its reason, as an estimate.
  @Test func dueCartridgeShowsWatchWithItsReasonAndEstimate() throws {
    var harness = Harness()
    let id = try Self.cartridge(&harness, year: 1994)
    let signal = try #require(try Self.signals(harness, id).first)
    #expect(signal.clock == "saveBattery")
    #expect(signal.status == .watch)
    #expect(signal.reason == .battery(since: 1994, swapped: false, lastsYears: 25...35))
    #expect(signal.isEstimate)
    #expect(signal.changesAt == Calendar.utc.date(from: DateComponents(year: 2029, month: 1, day: 1)))
  }

  /// F15's done-when, second half: logging a swap, an ordinary `serviced` event, clears it.
  @Test func loggingASwapClearsIt() throws {
    var harness = Harness()
    let id = try Self.cartridge(&harness, year: 1994)
    try harness.perform(.logEvent(id, kind: ShelfEvent.Kind.servicedKind, note: "Battery swap"))
    let signal = try #require(try Self.signals(harness, id).first)
    #expect(signal.status == .good)
    #expect(signal.reason == .battery(since: 2027, swapped: true, lastsYears: 25...35))
    #expect(!signal.status.needsAttention)
  }

  @Test func pastItsLifespanIsAct() throws {
    var harness = Harness()
    let id = try Self.cartridge(&harness, year: 1990)
    let signal = try #require(try Self.signals(harness, id).first)
    #expect(signal.status == .act)
    #expect(signal.changesAt == nil)
  }

  @Test func aFittedDateWinsOverTheReleaseYear() throws {
    var harness = Harness()
    let fitted = try #require(Calendar.utc.date(from: DateComponents(year: 2015, month: 6, day: 1)))
    let id = try Self.cartridge(&harness, year: 1994, values: [.field("saveBattery"): .date(fitted)])
    let signal = try #require(try Self.signals(harness, id).first)
    #expect(signal.status == .good)
    #expect(signal.reason == .battery(since: 2015, swapped: false, lastsYears: 25...35))
  }

  @Test func withNothingToReadThereIsNoSignal() throws {
    var harness = Harness()
    let id = try Self.cartridge(&harness, year: nil)
    #expect(try Self.signals(harness, id).isEmpty)
  }

  /// Neo Geo carts carry no battery: the subtype says `clock: none`.
  @Test func aSubtypeWithoutTheClockHasNoSignal() throws {
    var harness = Harness()
    let id = try harness.add(
      subtype: "neo-geo",
      values: [.field("region"): .text("NTSC-J"), .field("board"): .text("AES"), .year: .year(1990)]
    )
    #expect(try Self.signals(harness, id).isEmpty)
  }
}

/// The other library clocks, over values alone.
@Suite struct ClockTests {
  static func date(_ year: Int, _ month: Int = 1, _ day: Int = 1) -> Date {
    Calendar.utc.date(from: DateComponents(year: year, month: month, day: day))!
  }

  static func reading(_ values: [FieldKey: FieldValue], serviced: Date? = nil, now: Date) -> ClockReading {
    ClockReading(values: values, lastServiced: serviced, now: now, calendar: .utc)
  }

  static func signal(_ clock: String, _ values: [FieldKey: FieldValue], serviced: Date? = nil, now: Date) -> Signal? {
    reading(values, serviced: serviced, now: now).signal(ClockLibrary.definition(clock)!)
  }

  @Test func codeExpiryWatchesInsideSixtyDaysAndActsOnceExpired() {
    let values: [FieldKey: FieldValue] = [.field("codeExpires"): .date(Self.date(2027, 6, 30))]
    #expect(Self.signal("codeExpiry", values, now: Self.date(2027, 1, 1))?.status == .good)
    #expect(Self.signal("codeExpiry", values, now: Self.date(2027, 6, 1))?.status == .watch)
    #expect(Self.signal("codeExpiry", values, now: Self.date(2027, 7, 1))?.status == .act)
    #expect(Self.signal("codeExpiry", [:], now: Self.date(2027, 1, 1)) == nil)
  }

  @Test func drinkingWindowWatchesFromAYearBeforeAndActsInItsLastYear() {
    let values: [FieldKey: FieldValue] = [.field("drinkingWindow"): .yearRange(from: 2030, to: 2040)]
    #expect(Self.signal("drinkingWindow", values, now: Self.date(2028, 6))?.status == .good)
    #expect(Self.signal("drinkingWindow", values, now: Self.date(2029, 6))?.status == .watch)
    #expect(Self.signal("drinkingWindow", values, now: Self.date(2035))?.status == .watch)
    #expect(Self.signal("drinkingWindow", values, now: Self.date(2040, 2))?.status == .act)
    #expect(Self.signal("drinkingWindow", values, now: Self.date(2028))?.reason == .drinkingWindow(2030...2040))
  }

  @Test func serviceRiskNeedsAKnownServiceAndActsAtTwiceTheInterval() {
    let last = Self.date(2024, 3)
    let values: [FieldKey: FieldValue] = [.field("lastServiced"): .date(last)]
    #expect(Self.signal("serviceRisk", [:], now: Self.date(2027)) == nil)
    #expect(Self.signal("serviceRisk", values, now: Self.date(2025))?.status == .good)
    #expect(Self.signal("serviceRisk", values, now: Self.date(2026, 6))?.status == .watch)
    #expect(Self.signal("serviceRisk", values, now: Self.date(2028, 6))?.status == .act)
    #expect(Self.signal("serviceRisk", [:], serviced: Self.date(2026), now: Self.date(2027))?.status == .good)
  }

  @Test func mediaRotWatchesWhenACheckIsDueAndActsWhenABackupIsOverdue() {
    let values: [FieldKey: FieldValue] = [.year: .year(2023)]
    let due = Self.signal("mediaRot", values, now: Self.date(2025, 6))
    #expect(due?.status == .watch)
    #expect(due?.reason == .checked(since: 2023, wasChecked: false, everyYears: 2))
    #expect(due?.changesAt == Self.date(2027))
    #expect(Self.signal("mediaRot", [.year: .year(1998)], now: Self.date(2027))?.status == .act)
    let checked = Self.signal("mediaRot", values, serviced: Self.date(2026, 6), now: Self.date(2027))
    #expect(checked?.status == .good)
    #expect(checked?.changesAt == Self.date(2028, 6))
  }

  /// D-58: a backup resets the media clocks like a check does.
  @Test func aBackupResetsTheMediaClocks() {
    let reading = ClockReading(
      values: [.year: .year(1998)],
      lastServiced: nil,
      lastBackedUp: Self.date(2026, 6),
      now: Self.date(2027),
      calendar: .utc
    )
    let signal = reading.signal(ClockLibrary.definition("mediaRot")!)
    #expect(signal?.status == .good)
    #expect(signal?.reason == .checked(since: 2026, wasChecked: true, everyYears: 2))
  }

  @Test func unfinishedIsOptInAndWatchesAfterAYearOfPlaying() throws {
    var harness = Harness()
    let id = try SaveBatteryClockTests.cartridge(&harness, year: nil)
    try harness.perform(.edit(id, values: [.field("playStatus"): .text("Playing")]))
    let started = try #require(harness.log.last?.at)
    let object = try #require(harness.shelf.objects[id])
    let type = try Harness.catalogue.resolve(object.typeID, subtype: object.subtype)
    let later = Calendar.utc.date(byAdding: .month, value: 14, to: started)!
    let off = TegolaModel.signals(for: object, type: type, now: later, calendar: .utc)
    #expect(off.isEmpty)
    let on = TegolaModel.signals(
      for: object,
      type: type,
      now: later,
      calendar: .utc,
      optedIn: ["unfinished"]
    )
    #expect(on == [Signal(clock: "unfinished", status: .watch, reason: .unfinished(since: started), changesAt: nil)])
    try harness.perform(.edit(id, values: [.field("playStatus"): .text("Finished")]))
    let finished = try #require(harness.shelf.objects[id])
    #expect(
      TegolaModel.signals(
        for: finished,
        type: type,
        now: later,
        calendar: .utc,
        optedIn: ["unfinished"]
      ).isEmpty
    )
  }

  /// Disc rot is held back on v1's video games (PD-018): a Saturn disc gives no signal.
  @Test func aPendingClockGivesNoSignal() throws {
    var harness = Harness()
    let id = try harness.add(subtype: "saturn", values: [.field("region"): .text("NTSC-J"), .year: .year(1995)])
    #expect(try SaveBatteryClockTests.signals(harness, id).isEmpty)
  }

  /// Every clock in the library has a function; a new name without one fails here, not on a shelf.
  @Test func everyLibraryClockHasAFunction() {
    let values: [FieldKey: FieldValue] = [
      .year: .year(1995), .field("saveBattery"): .date(Self.date(1995)), .field("codeExpires"): .date(Self.date(2030)),
      .field("drinkingWindow"): .yearRange(from: 2030, to: 2035), .field("lastServiced"): .date(Self.date(2020)),
    ]
    let reading = ClockReading(
      values: values,
      lastServiced: nil,
      playingSince: Self.date(2025),
      now: Self.date(2027),
      calendar: .utc
    )
    for clock in ClockLibrary.all {
      #expect(reading.signal(clock) != nil, "\(clock.name)")
    }
  }
}

import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

/// An object with just the values a clock reads.
func clockObject(values: [FieldKey: FieldValue] = [:], latestLog: [String: Date]? = nil) -> ShelfObject {
  ShelfObject(
    id: ObjectID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
    collectionID: CollectionID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!),
    typeID: "video-game", subtype: "game-boy", workID: nil, values: values, auto: [], typed: [], placeID: nil,
    bulk: .rows, quantity: 1, ownership: .owned, identity: .confirmed, isGrail: false, mightLetGo: false,
    priority: nil, priceCap: nil, letGo: nil, promotedFrom: nil, latestLog: latestLog,
    createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
}

let utc: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "UTC")!
  return calendar
}()

func day(_ year: Int, _ month: Int = 1, _ day: Int = 1) -> Date {
  utc.date(from: DateComponents(year: year, month: month, day: day))!
}

func signal(_ clock: String, _ object: ShelfObject, at now: Date) -> ClockSignal? {
  Clocks.signal(ClockReference(clock), for: object, now: now, calendar: utc)
}

@Suite struct SaveBatteryClockTests {
  /// Lifespan 25 years, watch 3 years before (ClockLibrary).
  @Test func aGameFrom1995WithTheOriginalBattery() {
    let game = clockObject(values: [.year: .year(1995)])
    #expect(signal("saveBattery", game, at: day(2016, 12, 31)) == nil)
    #expect(signal("saveBattery", game, at: day(2017))?.status == .watch)
    #expect(signal("saveBattery", game, at: day(2017))?.reason == .batteryAging(fitted: 1995, lifespanYears: 25))
    #expect(signal("saveBattery", game, at: day(2017))?.changesAt == day(2020))
    #expect(signal("saveBattery", game, at: day(2020))?.status == .act)
    #expect(signal("saveBattery", game, at: day(2020))?.reason == .batteryPastLifespan(fitted: 1995, lifespanYears: 25))
  }

  /// PLAN §4.4 journey 5: logging a battery swap clears the line.
  @Test func loggingASwapClearsIt() {
    let swapped = clockObject(values: [.year: .year(1995)], latestLog: [CareKind.batterySwapped: day(2025, 6)])
    #expect(signal("saveBattery", swapped, at: day(2026, 11)) == nil)
  }

  /// The field records a replacement the collector typed; the later of it and a logged swap counts.
  @Test func theLaterOfTheFieldAndALoggedSwapCounts() {
    let typed = clockObject(values: [.year: .year(1995), .field("saveBattery"): .date(day(2001))])
    #expect(signal("saveBattery", typed, at: day(2024))?.reason == .batteryAging(fitted: 2001, lifespanYears: 25))
    let both = clockObject(
      values: [.year: .year(1995), .field("saveBattery"): .date(day(2001))],
      latestLog: [CareKind.batterySwapped: day(2020)])
    #expect(signal("saveBattery", both, at: day(2026)) == nil)
  }

  @Test func noYearAndNoDateMeansNothingToSay() {
    #expect(signal("saveBattery", clockObject(), at: day(2026)) == nil)
  }
}

@Suite struct CheckDueClockTests {
  /// Every 5 years for disc rot, 2 for tape; never more than watch (PD-018).
  @Test func discRotIsWatchAtMostAndAResetByACheck() {
    let cd = clockObject(values: [.year: .year(1990)])
    #expect(signal("discRot", cd, at: day(2026))?.status == .watch)
    #expect(signal("discRot", cd, at: day(2026))?.reason == .checkDue(since: 1990, everyYears: 5))
    let checked = clockObject(values: [.year: .year(1990)], latestLog: [CareKind.checked: day(2024)])
    #expect(signal("discRot", checked, at: day(2026)) == nil)
    #expect(signal("discRot", checked, at: day(2029))?.reason == .checkDue(since: 2024, everyYears: 5))
  }

  @Test func mediaRotUsesItsOwnInterval() {
    let tape = clockObject(values: [.year: .year(2024)])
    #expect(signal("mediaRot", tape, at: day(2025, 12, 31)) == nil)
    #expect(signal("mediaRot", tape, at: day(2026))?.reason == .checkDue(since: 2024, everyYears: 2))
  }

  /// D-37, D-56: a clock held pending says nothing anywhere.
  @Test func aPendingClockSaysNothing() {
    let old = clockObject(values: [.year: .year(1980)])
    #expect(signal("discRot-pending", old, at: day(2026)) == nil)
  }
}

@Suite struct CodeExpiryClockTests {
  @Test func watchFor60DaysThenAct() {
    let card = clockObject(values: [.field("expires"): .date(day(2026, 12, 31))])
    #expect(signal("codeExpiry", card, at: day(2026, 10, 31)) == nil)
    #expect(signal("codeExpiry", card, at: day(2026, 11, 1))?.status == .watch)
    #expect(signal("codeExpiry", card, at: day(2026, 12, 31))?.status == .act)
  }
}

@Suite struct DrinkingWindowClockTests {
  let bottle = clockObject(values: [.field("drinkingWindow"): .yearRange(from: 2030, to: 2042)])

  @Test(arguments: [
    (2028, nil), (2029, ObjectStatus.watch), (2030, .good), (2041, .good), (2042, .watch), (2043, .act),
  ] as [(Int, ObjectStatus?)])
  func throughTheWindow(_ year: Int, _ status: ObjectStatus?) {
    #expect(signal("drinkingWindow", bottle, at: day(year, 6))?.status == status)
  }

  /// One Roof's example: the open window is the good moment, "Drink it".
  @Test func theOpenWindowIsTheGoodMoment() {
    #expect(signal("drinkingWindow", bottle, at: day(2035))?.reason == .windowOpen(from: 2030, to: 2042))
  }
}

@Suite struct ServiceRiskClockTests {
  @Test func watchAfterOneIntervalActAfterTwo() {
    let console = clockObject(values: [.year: .year(2020)], latestLog: [CareKind.serviced: day(2024, 3)])
    #expect(signal("serviceRisk", console, at: day(2026, 2)) == nil)
    #expect(signal("serviceRisk", console, at: day(2026, 3))?.status == .watch)
    #expect(signal("serviceRisk", console, at: day(2028, 3))?.status == .act)
  }
}

@Suite struct ClockLibraryCoverageTests {
  /// Every clock in the library has a function: a name with none would silently say nothing.
  @Test(arguments: ClockLibrary.all.map(\.name))
  func everyLibraryClockComputesSomething(_ name: String) {
    let everything = clockObject(
      values: [
        .year: .year(1950), .field("expires"): .date(day(1960)),
        .field("drinkingWindow"): .yearRange(from: 1960, to: 1970),
      ])
    #expect(signal(name, everything, at: day(2026)) != nil, "\(name) computed nothing")
  }

  /// Every clock a v1 type names resolves to a library clock (D-37).
  @Test func everyClockAV1TypeNamesIsInTheLibrary() throws {
    let catalogue = try Catalogue.bundled()
    for manifest in catalogue.enabled {
      for subtype in [nil] + manifest.subtypes.map(\.key) {
        for clock in try catalogue.resolve(manifest.id, subtype: subtype).clocks {
          #expect(clock.definition != nil, "\(manifest.id.rawValue)/\(subtype ?? "-"): \(clock.name)")
        }
      }
    }
  }

  /// D-56: no disc-rot clock on video games (PD-018); it's held pending.
  @Test func videoGamesNeverRunDiscRot() throws {
    let catalogue = try Catalogue.bundled()
    let manifest = try #require(catalogue.manifest("video-game"))
    for subtype in manifest.subtypes.map(\.key) {
      let clocks = try catalogue.resolve("video-game", subtype: subtype).clocks
      #expect(!clocks.contains { $0.name == "discRot" && !$0.isPending }, "\(subtype)")
    }
  }
}

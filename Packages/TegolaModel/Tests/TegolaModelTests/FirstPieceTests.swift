import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

/// The first piece (PLAN F2, page 46): one write that lands a named piece in a collection the collector never created,
/// with its story as the first history line and no acquired date.
@Suite struct FirstPieceTests {
  let catalogue = Harness.catalogue

  func ocarina() -> ObjectDraft {
    ObjectDraft(type: "video-game", subtype: "n64", values: [.title: .text("Ocarina of Time"), .year: .year(1998)])
  }

  @Test func itLandsInTheCollectionItsTypeNames() throws {
    var harness = Harness()
    let events = try harness.perform(.firstPiece(ocarina(), story: "  Had it since I was a kid ", catalogue: catalogue))
    #expect(harness.shelf.collections.values.map(\.name) == ["The Library"])
    guard case .added(let object, let origin) = events.last?.kind else {
      Issue.record("no added event")
      return
    }
    // The story is trimmed, and it's history: the first line the object's History slot shows.
    #expect(origin == .firstPiece(story: "Had it since I was a kid"))
    #expect(events.last?.kind.readsAsHistory == true)
    #expect(object.identity == .confirmed)
    // PD-165: the app never writes when it was acquired.
    #expect(object.values[.acquired] == nil)
  }

  @Test func onlyTheShelfsFirstObjectIsTheFirstPiece() throws {
    var harness = Harness()
    _ = try harness.add()
    #expect(throws: ShelfRuleViolation.notTheFirstPiece) {
      try harness.perform(.firstPiece(ocarina(), story: "", catalogue: catalogue))
    }
  }

  /// 46, 2B: "Watches aren't a full type yet. It's saved safely as a Thing."
  @Test func aTypeThatHasntShippedIsSavedAsAThingThatWaits() throws {
    var harness = Harness()
    let draft = ObjectDraft.recognised(
      as: "watches",
      values: [.title: .text("Omega Seamaster"), .year: .year(1968), .field("caliber"): .text("565")],
      catalogue: catalogue
    )
    #expect(draft.type == "thing")
    #expect(draft.awaitingType == "watches")
    // A watch's own fields don't exist on a Thing; the title and year mean the same everywhere.
    #expect(draft.values == [.title: .text("Omega Seamaster"), .year: .year(1968)])
    try harness.perform(.firstPiece(draft, story: "From my grandfather", catalogue: catalogue))
    #expect(harness.shelf.collections.values.map(\.name) == ["Collection"])
    #expect(harness.shelf.waiting(for: "watches").map(\.title) == ["Omega Seamaster"])
    #expect(harness.shelf.waiting(for: "wine").isEmpty)
  }

  @Test func aShippedTypeIsSavedAsItself() {
    let draft = ObjectDraft.recognised(as: "video-game", subtype: "n64", values: ocarina().values, catalogue: catalogue)
    #expect(draft == ocarina())
  }

  @Test(arguments: [
    ObjectDraft(type: "video-game", values: [.title: .text("Ocarina")], awaitingType: "watches"),
    ObjectDraft(type: "thing", values: [.title: .text("Ocarina")], awaitingType: "video-game"),
    ObjectDraft(type: "thing", values: [.title: .text("Ocarina")], awaitingType: "spaceships"),
  ])
  func onlyAThingWaitsAndOnlyForATypeThatHasntShipped(_ draft: ObjectDraft) {
    var harness = Harness()
    #expect(throws: ShelfRuleViolation.cantAwaitType(draft.awaitingType!)) {
      try harness.perform(.add(draft, to: .new(name: "Things"), origin: .typed))
    }
  }

  @Test func letGoPiecesDontWait() throws {
    var harness = Harness()
    let draft = ObjectDraft.recognised(as: "watches", values: [.title: .text("Seiko 5")], catalogue: catalogue)
    let events = try harness.perform(.add(draft, to: .new(name: "Things"), origin: .typed))
    let id = try #require(
      events.compactMap { if case .added(let object, _) = $0.kind { object.id } else { nil } }.first
    )
    try harness.perform(.letGo(id, .gifted))
    #expect(harness.shelf.waiting(for: "watches").isEmpty)
  }
}

/// Screen 03: the piece already tells its collector something.
@Suite struct FirstPiecePayoffTests {
  let catalogue = Harness.catalogue

  /// "Your save is at risk. The cart's CR2032 has been running since 1998."
  @Test func ocarinaOfTimesSaveIsAtRisk() throws {
    let type = try catalogue.resolve("video-game", subtype: "n64")
    let cart = clockObject(values: [.year: .year(1998)])
    let payoff = FirstPiecePayoff(object: cart, type: type, now: day(2026, 11), calendar: utc)
    guard case .now(let signal) = payoff.line else {
      Issue.record("no signal: \(String(describing: payoff.line))")
      return
    }
    #expect(signal.reason == .batteryPastLifespan(fitted: 1998, lifespanYears: 25))
  }

  /// "Not yet. Soon. Opens in 2027. We'll tell you when it's time." Wine ships as data, so this reads the type
  /// directly: in v1 a bottle is a Thing waiting for it, and a Thing has no clock.
  @Test func aWineThatIsntReadyYetSaysWhen() throws {
    let type = try catalogue.resolve("wine", subtype: nil)
    let bottle = clockObject(values: [.field("drinkingWindow"): .yearRange(from: 2027, to: 2040)])
    let payoff = FirstPiecePayoff(object: bottle, type: type, now: day(2021, 6), calendar: utc)
    #expect(payoff.line == .later(clock: "drinkingWindow", from: day(2026)))
  }

  /// A battery fitted recently is quiet now, and the payoff says when it won't be.
  @Test func aQuietClockSaysWhenItWillSpeak() throws {
    let type = try catalogue.resolve("video-game", subtype: "game-boy")
    let cart = clockObject(values: [.year: .year(1998)], latestLog: [CareKind.batterySwapped: day(2024, 3)])
    let payoff = FirstPiecePayoff(object: cart, type: type, now: day(2026, 11), calendar: utc)
    #expect(payoff.line == .later(clock: "saveBattery", from: day(2046, 3)))
  }

  @Test func aPieceWithNoClockHasOnlyItsStory() throws {
    let type = try catalogue.resolve("board-games", subtype: nil)
    let payoff = FirstPiecePayoff(
      object: clockObject(values: [.year: .year(1995)]),
      type: type,
      now: day(2026),
      calendar: utc
    )
    #expect(payoff.line == nil)
  }
}

@Suite struct FirstSignalDateTests {
  @Test func eachClockSaysWhenItFirstSpeaks() {
    let old = clockObject(values: [.year: .year(2020)])
    #expect(Clocks.firstSignalDate(ClockReference("saveBattery"), for: old, now: day(2026), calendar: utc) == day(2042))
    #expect(Clocks.firstSignalDate(ClockReference("discRot"), for: old, now: day(2024), calendar: utc) == day(2025))
    #expect(Clocks.firstSignalDate(ClockReference("serviceRisk"), for: old, now: day(2020, 6), calendar: utc) != nil)
    let card = clockObject(values: [.field("expires"): .date(day(2027, 3, 1))])
    #expect(
      Clocks.firstSignalDate(ClockReference("codeExpiry"), for: card, now: day(2026), calendar: utc)
        == day(2026, 12, 31)
    )
  }

  @Test func aClockThatAlreadySpeaksOrIsPendingHasNoDate() {
    let old = clockObject(values: [.year: .year(1990)])
    #expect(Clocks.firstSignalDate(ClockReference("saveBattery"), for: old, now: day(2026), calendar: utc) == nil)
    #expect(Clocks.firstSignalDate(ClockReference("discRot-pending"), for: old, now: day(1991), calendar: utc) == nil)
    #expect(
      Clocks.firstSignalDate(ClockReference("saveBattery"), for: clockObject(), now: day(2026), calendar: utc) == nil
    )
  }
}

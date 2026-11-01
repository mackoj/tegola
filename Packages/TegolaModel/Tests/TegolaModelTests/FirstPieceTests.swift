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

  func day(_ year: Int, _ month: Int = 1, _ day: Int = 1) -> Date {
    Calendar.utc.date(from: DateComponents(year: year, month: month, day: day))!
  }

  /// An object of `type` with these values, through `plan` and `apply`, and a logged service when asked.
  func piece(
    _ type: TypeManifest.ID = "video-game",
    subtype: String? = nil,
    values: [FieldKey: FieldValue],
    serviced: Bool = false
  ) throws -> (ShelfObject, at: Date) {
    var harness = Harness()
    let id = try harness.add(type, subtype: subtype, values: values)
    let at = harness.clock
    if serviced { try harness.perform(.logEvent(id, kind: ShelfEvent.Kind.servicedKind, note: "")) }
    return (try #require(harness.shelf.objects[id]), at)
  }

  /// "Your save is at risk. The cart's CR2032 has been running since 1998."
  @Test func ocarinaOfTimesSaveIsAtRisk() throws {
    let type = try catalogue.resolve("video-game", subtype: "n64")
    let (cart, _) = try piece(subtype: "n64", values: [.year: .year(1998)])
    let payoff = FirstPiecePayoff(object: cart, type: type, now: day(2026, 11), calendar: .utc)
    guard case .now(let signal) = payoff.line else {
      Issue.record("no signal: \(String(describing: payoff.line))")
      return
    }
    #expect(signal.status == .watch)
    #expect(signal.reason == .battery(since: 1998, swapped: false, lastsYears: 25...35))
  }

  /// "Not yet. Soon. Opens in 2027. We'll tell you when it's time." Wine ships as data, so this reads the type
  /// directly: in v1 a bottle is a Thing waiting for it, and a Thing has no clock.
  @Test func aWineThatIsntReadyYetSaysWhen() throws {
    let type = try catalogue.resolve("wine", subtype: nil)
    var (bottle, _) = try piece(values: [:])
    bottle.values = [.field("drinkingWindow"): .yearRange(from: 2027, to: 2040)]
    let payoff = FirstPiecePayoff(object: bottle, type: type, now: day(2021, 6), calendar: .utc)
    #expect(payoff.line == .later(clock: "drinkingWindow", from: day(2026)))
  }

  /// A battery swapped recently reads good now, and the payoff says when it won't.
  @Test func aQuietClockSaysWhenItWillSpeak() throws {
    let type = try catalogue.resolve("video-game", subtype: "game-boy")
    let (cart, _) = try piece(subtype: "game-boy", values: [.year: .year(1998)], serviced: true)
    let swapped = try #require(cart.signalState?.lastServiced)
    let payoff = FirstPiecePayoff(object: cart, type: type, now: swapped, calendar: .utc)
    let watch = try #require(Calendar.utc.date(byAdding: .year, value: 25, to: swapped))
    #expect(payoff.line == .later(clock: "saveBattery", from: watch))
  }

  @Test func aPieceWithNoClockHasOnlyItsStory() throws {
    let type = try catalogue.resolve("board-games", subtype: nil)
    let (game, _) = try piece("board-games", values: [.year: .year(1995)])
    let payoff = FirstPiecePayoff(object: game, type: type, now: day(2026), calendar: .utc)
    #expect(payoff.line == nil)
  }
}

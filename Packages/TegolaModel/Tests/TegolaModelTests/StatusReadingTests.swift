import Foundation
import TegolaCatalogue
import TegolaModelTesting
import Testing

@testable import TegolaModel

@Suite struct StatusReadingTests {
  /// 2027-01-15: a Game Boy cartridge from 1995 is past its battery's 25 years.
  let now = Harness.start

  func reading(_ harness: Harness, _ id: ObjectID, at now: Date? = nil) throws -> StatusReading {
    try #require(
      StatusReading.all(shelf: harness.shelf, catalogue: Harness.catalogue, now: now ?? self.now, calendar: utc)[id]
    )
  }

  @Test func aClockSpeaksForAnOwnedObject() throws {
    var harness = Harness()
    let game = try harness.add(subtype: "game-boy", values: [.year: .year(1995)])
    let reading = try reading(harness, game)
    #expect(reading.status == .act)
    #expect(reading.isSignal)
    guard case .clock(let signal) = reading.reason else { Issue.record("\(reading)"); return }
    #expect(signal.clock == "saveBattery")
  }

  @Test func letGoIsGoneWhateverElseIsTrue() throws {
    var harness = Harness()
    let game = try harness.add(subtype: "game-boy", values: [.year: .year(1995)])
    try harness.perform(.letGo(game, .sold(price: nil)))
    #expect(try reading(harness, game) == StatusReading(status: .gone, reason: .letGo))
  }

  @Test func anOverdueLoanIsActAndASignal() throws {
    var harness = Harness()
    let game = try harness.add()
    try harness.perform(.lend(game, to: .new(name: "Dara"), due: now + 3600, note: ""))
    #expect(try reading(harness, game).status == .fine)
    guard case .lent = try reading(harness, game).reason else { Issue.record("not lent"); return }
    let overdue = try reading(harness, game, at: now + 7200)
    #expect(overdue.status == .act)
    #expect(overdue.isSignal)
  }

  /// To tidy is the Today strip's own line: the chip is watch, but it doesn't also count as needing attention.
  @Test func anUnconfirmedCaptureIsWatchButNotASignal() throws {
    var harness = Harness()
    let capture = try harness.add(origin: .captured)
    let reading = try reading(harness, capture)
    #expect(reading == StatusReading(status: .watch, reason: .unconfirmed))
    #expect(!reading.isSignal)
  }

  /// Clocks are about the collector's own things.
  @Test func wantedAndBorrowedObjectsRunNoClock() throws {
    var harness = Harness()
    let wanted = try harness.add(subtype: "game-boy", values: [.year: .year(1995)], ownership: .wanted)
    let borrowed = try harness.add(subtype: "game-boy", values: [.year: .year(1995)], ownership: .borrowed)
    #expect(try reading(harness, wanted).reason == .settled)
    #expect(try reading(harness, borrowed).reason == .settled)
  }

  @Test func aDismissedClockStaysHiddenUntilItGetsWorse() throws {
    var harness = Harness()
    let game = try harness.add(subtype: "game-boy", values: [.year: .year(2003)])
    // 2027: 24 years since 2003, so watch (it turns act in 2028).
    #expect(try reading(harness, game).status == .watch)
    harness.shelf.objects[game]?.dismissed = ["saveBattery": .watch]
    #expect(try reading(harness, game).reason == .settled)
    let laterStill = utc.date(from: DateComponents(year: 2028, month: 6, day: 1))!
    #expect(try reading(harness, game, at: laterStill).status == .act)
  }

  @Test func theMostUrgentCandidateWins() throws {
    var harness = Harness()
    // Unconfirmed (watch) and a battery past its lifespan (act): act wins, and it's the clock.
    let capture = try harness.add(subtype: "game-boy", values: [.year: .year(1995)], origin: .captured)
    let reading = try reading(harness, capture)
    #expect(reading.status == .act)
    guard case .clock = reading.reason else { Issue.record("\(reading)"); return }
  }

  /// Over random command sequences, per v1 type: let go always reads gone, and only clocks and overdue loans count
  /// as needing attention.
  @Test(arguments: Catalogue.enabledInV1)
  func readingsHoldOverRandomCommands(_ type: TypeManifest.ID) throws {
    for seed in 1...UInt64(20) {
      var harness = Harness()
      var generator = CommandGenerator(type: type, catalogue: Harness.catalogue, seed: seed &* 104_729)
      for _ in 0..<60 {
        let (command, source) = generator.next(on: harness.shelf)
        _ = try? harness.perform(command, as: source)
      }
      let readings = StatusReading.all(shelf: harness.shelf, catalogue: Harness.catalogue, now: now, calendar: utc)
      for object in harness.shelf.objects.values {
        let reading = try #require(readings[object.id])
        if object.letGo != nil { #expect(reading.status == .gone, "seed \(seed)") }
        switch reading.reason {
        case .clock, .overdue: #expect(reading.isSignal == reading.status.needsAttention, "seed \(seed)")
        default: #expect(!reading.isSignal, "seed \(seed)")
        }
      }
    }
  }
}

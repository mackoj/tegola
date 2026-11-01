import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

/// T8.4: board 21's rules, as tests.
@Suite struct WeeklyNudgeTests {
  static let day: TimeInterval = 86_400

  @Test func silenceIsTheRewardWhenNothingIsUnfinished() throws {
    var harness = Harness()
    _ = try harness.add("music", "Kid A")
    #expect(WeeklyNudge.next(shelf: harness.shelf, tone: .dry, lastSent: nil, now: Harness.start) == nil)
  }

  @Test func itNamesTheOldestUnconfirmedObjectAndCountsTheRest() throws {
    var harness = Harness()
    let first = try harness.add("music", "Saga #1", origin: .captured)
    _ = try harness.add("music", "Saga #2", origin: .imported)
    _ = try harness.add("music", "Kid A")
    let nudge = try #require(WeeklyNudge.next(shelf: harness.shelf, tone: .plain, lastSent: nil, now: Harness.start))
    #expect(nudge.kind == .unconfirmed)
    #expect(nudge.objectID == first)
    #expect(nudge.title == "Saga #1")
    #expect(nudge.count == 2)
    #expect(nudge.at == Harness.start)
  }

  @Test func oneAWeekAtMostAndNoneWithTheToneOff() throws {
    var harness = Harness()
    _ = try harness.add("music", "Saga #1", origin: .captured)
    let last = Harness.start - 2 * Self.day
    let nudge = try #require(WeeklyNudge.next(shelf: harness.shelf, tone: .dry, lastSent: last, now: Harness.start))
    #expect(nudge.at == last + 7 * Self.day)
    #expect(WeeklyNudge.next(shelf: harness.shelf, tone: .off, lastSent: nil, now: Harness.start) == nil)
  }

  /// Let go is finished business; a wish isn't the collector's to finish yet.
  @Test func letGoAndWantedObjectsNeverNudge() throws {
    var harness = Harness()
    let gone = try harness.add("music", "Saga #1", origin: .captured)
    try harness.perform(.letGo(gone, .lost))
    _ = try harness.add("music", "Debut", ownership: .wanted, origin: .captured)
    #expect(WeeklyNudge.next(shelf: harness.shelf, tone: .dry, lastSent: nil, now: Harness.start) == nil)
  }
}

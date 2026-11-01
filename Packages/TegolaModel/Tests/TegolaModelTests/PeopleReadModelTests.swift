import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

@Suite struct PeopleReadModelTests {
  static let day: TimeInterval = 86_400

  /// A shelf with Dara holding two things (one overdue, one with no date), Max one due later, and Anne's record on
  /// the shelf; Dara has also brought one back after four days.
  struct Lending {
    var harness = Harness()
    var overdue: ObjectID!
    var undated: ObjectID!
    var dueLater: ObjectID!
    var returned: ObjectID!
    var borrowed: ObjectID!
    var dara: PersonID!
    var now: Date { Harness.start + 20 * PeopleReadModelTests.day }

    init() throws {
      let day = PeopleReadModelTests.day
      returned = try harness.add("music", "Kid A")
      try harness.perform(.lend(returned, to: .new(name: "Dara"), due: nil, note: ""))
      dara = try #require(harness.shelf.persons.values.first?.id)
      harness.clock += 4 * day
      let loan = try #require(harness.shelf.openLoan(on: returned))
      try harness.perform(.returnLoan(loan.id, condition: nil))

      overdue = try harness.add("music", "Homogenic")
      try harness.perform(.lend(overdue, to: .existing(dara), due: Harness.start + 10 * day, note: "For the drive"))
      undated = try harness.add("music", "Vespertine")
      try harness.perform(.lend(undated, to: .existing(dara), due: nil, note: ""))
      dueLater = try harness.add("music", "Debut")
      try harness.perform(.lend(dueLater, to: .new(name: "Max"), due: Harness.start + 30 * day, note: ""))
      borrowed = try harness.add("music", "Blue Train", ownership: .borrowed)
      try harness.perform(.markBorrowed(borrowed, from: .new(name: "Anne")))
    }
  }

  @Test func activityPutsOverdueFirstThenTheSoonestDueThenNoDate() throws {
    let lending = try Lending()
    let activity = Activity(shelf: lending.harness.shelf, now: lending.now)
    #expect(activity.out.map(\.objectID) == [lending.overdue, lending.dueLater, lending.undated])
    #expect(activity.returned.map(\.objectID) == [lending.returned])
    #expect(activity.borrowed.map(\.objectID) == [lending.borrowed])
    #expect(activity.byPerson.map(\.person.name) == ["Dara", "Max"])
    let dara = try #require(activity.byPerson.first)
    #expect(dara.loans.map(\.objectID) == [lending.overdue!, lending.undated!])
  }

  /// F13: Activity is the only tab with a badge, and the badge is gone when nothing is due.
  @Test func theBadgeCountsOverdueLoansAndIsGoneWhenNoneIs() throws {
    var lending = try Lending()
    #expect(Activity(shelf: lending.harness.shelf, now: Harness.start).badge == nil)
    #expect(Activity(shelf: lending.harness.shelf, now: lending.now).badge == 1)
    let loan = try #require(lending.harness.shelf.openLoan(on: lending.overdue))
    try lending.harness.perform(.returnLoan(loan.id, condition: nil))
    #expect(Activity(shelf: lending.harness.shelf, now: lending.now).badge == nil)
  }

  @Test func anEmptyShelfHasAnEmptyActivity() {
    let activity = Activity(shelf: Shelf(), now: Harness.start)
    #expect(activity.isEmpty)
    #expect(activity.badge == nil)
  }

  @Test func aPersonsRecordSaysWhatTheyHoldAndHowItWent() throws {
    let lending = try Lending()
    let record = try #require(PersonRecord(person: lending.dara, shelf: lending.harness.shelf, calendar: .gregorianUTC))
    #expect(record.person.name == "Dara")
    #expect(record.holdsNow.map(\.objectID) == [lending.overdue, lending.undated])
    #expect(record.loans.map(\.objectID) == [lending.undated, lending.overdue, lending.returned])
    #expect(record.lent == 3)
    #expect(record.returned == 1)
    #expect(record.averageDaysOut == 4)
    #expect(record.since == Harness.start + 60)
    #expect(record.lentToYou.isEmpty)
  }

  @Test func someoneWhoLentToYouHasThatOnTheirPage() throws {
    let lending = try Lending()
    let anne = try #require(lending.harness.shelf.persons.values.first { $0.name == "Anne" })
    let record = try #require(PersonRecord(person: anne.id, shelf: lending.harness.shelf, calendar: .gregorianUTC))
    #expect(record.lentToYou.map(\.objectID) == [lending.borrowed])
    #expect(record.lent == 0)
    #expect(record.averageDaysOut == nil)
  }

  @Test func aPersonWithNoLoansHasNothingInvented() throws {
    var shelf = Shelf()
    let id = PersonID(UUID())
    shelf.persons[id] = Person(id: id, name: "Théo", lastUsedAt: Harness.start)
    let record = try #require(PersonRecord(person: id, shelf: shelf, calendar: .gregorianUTC))
    #expect(record.loans.isEmpty)
    #expect(record.averageDaysOut == nil)
    #expect(record.since == nil)
    #expect(PersonRecord(person: PersonID(UUID()), shelf: shelf, calendar: .gregorianUTC) == nil)
  }

  @Test func thePickerListsTheMostRecentlyUsedFirst() throws {
    var lending = try Lending()
    #expect(lending.harness.shelf.recentPeople.map(\.name) == ["Anne", "Max", "Dara"])
    let loan = try #require(lending.harness.shelf.openLoan(on: lending.overdue))
    try lending.harness.perform(.returnLoan(loan.id, condition: nil))
    try lending.harness.perform(.lend(lending.overdue, to: .existing(lending.dara), due: nil, note: ""))
    #expect(lending.harness.shelf.recentPeople.map(\.name) == ["Dara", "Anne", "Max"])
  }

  /// Promise 4: lending doesn't change what counts, and borrowing never adds to it.
  @Test func lendingAndBorrowingLeaveTheCountAlone() throws {
    let lending = try Lending()
    #expect(ShelfSummary(shelf: lending.harness.shelf, money: .off, now: lending.now).count == 4)
  }
}

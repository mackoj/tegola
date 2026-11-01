import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

/// T7.3: one reminder on the due date, and what a nudge says (F13).
@Suite struct LoanReminderTests {
  static let day: TimeInterval = 86_400
  static let calendar = Calendar.gregorianUTC

  @Test func oneReminderForEachOpenLoanOutWithADateSoonestFirst() throws {
    var harness = Harness()
    let later = try harness.add("music", "Debut")
    try harness.perform(.lend(later, to: .new(name: "Max"), due: Harness.start + 30 * Self.day, note: ""))
    let sooner = try harness.add("music", "Homogenic")
    try harness.perform(.lend(sooner, to: .new(name: "Dara"), due: Harness.start + 7 * Self.day, note: ""))
    let undated = try harness.add("music", "Vespertine")
    try harness.perform(.lend(undated, to: .new(name: "Léa"), due: nil, note: ""))
    let borrowed = try harness.add("music", "Blue Train", ownership: .borrowed)
    try harness.perform(.markBorrowed(borrowed, from: .new(name: "Anne")))

    let reminders = harness.shelf.loanReminders(at: Harness.start, calendar: Self.calendar)
    #expect(reminders.map(\.objectID) == [sooner, later])
    #expect(reminders.first?.title == "Homogenic")
    #expect(reminders.first?.person == "Dara")
    #expect(reminders.first?.at == Harness.start + 7 * Self.day)
  }

  @Test func aReturnedOrOverdueLoanHasNoReminderButOneDueTodayDoes() throws {
    var harness = Harness()
    let today = try harness.add("music", "Kid A")
    let dueToday = Self.calendar.startOfDay(for: Harness.start)
    try harness.perform(.lend(today, to: .new(name: "Dara"), due: dueToday, note: ""))
    let overdue = try harness.add("music", "Amnesiac")
    try harness.perform(.lend(overdue, to: .new(name: "Max"), due: Harness.start - 2 * Self.day, note: ""))
    let back = try harness.add("music", "OK Computer")
    try harness.perform(.lend(back, to: .new(name: "Léa"), due: Harness.start + Self.day, note: ""))
    let loan = try #require(harness.shelf.openLoan(on: back))
    try harness.perform(.returnLoan(loan.id, condition: nil))

    #expect(harness.shelf.loanReminders(at: Harness.start, calendar: Self.calendar).map(\.objectID) == [today])
  }

  @Test func remindersStopAtTheLimit() throws {
    var harness = Harness()
    for index in 0..<(Shelf.loanReminderLimit + 3) {
      let id = try harness.add("music", "Record \(index)")
      try harness.perform(.lend(id, to: .new(name: "Max"), due: Harness.start + Double(index + 1) * Self.day, note: ""))
    }
    let reminders = harness.shelf.loanReminders(at: Harness.start, calendar: Self.calendar)
    #expect(reminders.count == Shelf.loanReminderLimit)
    #expect(reminders.first?.title == "Record 0")
  }

  @Test func aNudgeSaysWhatWhoHowLongAndHowLate() throws {
    var harness = Harness()
    let id = try harness.add(
      "music",
      "Homogenic",
      values: [.paid: .money(Money(minorUnits: 4_000, currency: Currency("EUR")!))]
    )
    try harness.perform(.lend(id, to: .new(name: "Dara"), due: Harness.start + 14 * Self.day, note: ""))
    let loan = try #require(harness.shelf.openLoan(on: id))

    let onTime = try #require(
      Nudge(loan: loan.id, shelf: harness.shelf, now: Harness.start + 10 * Self.day, calendar: Self.calendar)
    )
    #expect(onTime == Nudge(title: "Homogenic", person: "Dara", daysOut: 10, daysOverdue: nil))
    let late = try #require(
      Nudge(loan: loan.id, shelf: harness.shelf, now: Harness.start + 20 * Self.day, calendar: Self.calendar)
    )
    #expect(late.daysOut == 20)
    #expect(late.daysOverdue == 6)

    try harness.perform(.returnLoan(loan.id, condition: nil))
    #expect(Nudge(loan: loan.id, shelf: harness.shelf, now: Harness.start, calendar: Self.calendar) == nil)
  }

  /// Promise 5: a nudge has nowhere to put what was paid, or any other money.
  @Test func aNudgeCarriesNoMoney() throws {
    let nudge = Nudge(title: "Homogenic", person: "Dara", daysOut: 3, daysOverdue: nil)
    let fields = Mirror(reflecting: nudge).children.map { type(of: $0.value) }
    #expect(fields.allSatisfy { $0 == String.self || $0 == Int.self || $0 == Int?.self })
  }
}

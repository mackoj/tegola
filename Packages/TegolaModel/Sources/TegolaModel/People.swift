public import Foundation

extension Shelf {
  /// The people a collector picks from when lending or borrowing: the most recently used first, then by name (F13,
  /// board 18).
  public var recentPeople: [Person] {
    persons.values.sorted { lhs, rhs in
      if lhs.lastUsedAt != rhs.lastUsedAt { return lhs.lastUsedAt > rhs.lastUsedAt }
      return byName(lhs.name, rhs.name, lhs.id, rhs.id)
    }
  }

  /// The loans whose object is still on the shelf: a loan never outlives its object's row.
  var liveLoans: [Loan] { loans.values.filter { objects[$0.objectID] != nil } }
}

/// One person's page (board 19): what they hold now and how lending to them has gone. Every number is derived from
/// the loans; with no history there's nothing to say, and nothing is invented.
public struct PersonRecord: Hashable, Sendable {
  public let person: Person
  /// The collector's objects this person holds now, the longest out first.
  public let holdsNow: [Loan]
  /// This person's objects on the collector's shelf now (borrowed in), the longest held first.
  public let lentToYou: [Loan]
  /// Every loan with this person, both ways, newest first.
  public let loans: [Loan]
  /// Loans out to this person, open or closed.
  public let lent: Int
  /// Loans out that came back.
  public let returned: Int
  /// The average whole days a loan out stayed out, over the ones that came back; nil when none has.
  public let averageDaysOut: Int?
  /// When the first loan with this person began; nil when there's none.
  public let since: Date?

  public init?(person id: PersonID, shelf: Shelf, calendar: Calendar) {
    guard let person = shelf.persons[id] else { return nil }
    self.person = person
    let theirs = shelf.liveLoans.filter { $0.personID == id }
    loans = theirs.sorted { ($0.openedAt, $0.id) > ($1.openedAt, $1.id) }
    holdsNow = theirs.filter { $0.isOpen && $0.direction == .out }.sorted(by: Loan.longestOutFirst)
    lentToYou = theirs.filter { $0.isOpen && $0.direction == .in }.sorted(by: Loan.longestOutFirst)
    let out = theirs.filter { $0.direction == .out }
    lent = out.count
    let back = out.compactMap { loan in loan.closedAt.map { (loan.openedAt, $0) } }
    returned = back.count
    averageDaysOut =
      back.isEmpty
      ? nil
      : back.map { calendar.dateComponents([.day], from: $0.0, to: $0.1).day ?? 0 }.reduce(0, +) / back.count
    since = theirs.map(\.openedAt).min()
  }
}

/// The Activity tab (F13, boards 17 and 22): loans out, what came back, who holds what, and what's borrowed in.
public struct Activity: Hashable, Sendable {
  /// One person and the collector's objects they hold now.
  public struct PersonLoans: Hashable, Sendable, Identifiable {
    public let person: Person
    public let loans: [Loan]
    public var id: PersonID { person.id }
  }

  /// Open loans out: overdue first (the longest overdue leading), then the soonest due, then those with no date,
  /// the longest out first.
  public let out: [Loan]
  /// Loans out that came back, the most recent return first.
  public let returned: [Loan]
  /// The people holding something now, by name.
  public let byPerson: [PersonLoans]
  /// Someone else's objects on the shelf, the longest held first. They never count (promise 4).
  public let borrowed: [Loan]
  /// Loans out past their due date.
  public let overdue: Int

  public init(shelf: Shelf, now: Date) {
    let live = shelf.liveLoans
    out = live.filter { $0.isOpen && $0.direction == .out }.sorted { lhs, rhs in
      switch (lhs.dueAt, rhs.dueAt) {
      case (let l?, let r?): (l, lhs.id) < (r, rhs.id)
      case (.some, nil): true
      case (nil, .some): false
      case (nil, nil): Loan.longestOutFirst(lhs, rhs)
      }
    }
    returned = live.filter { $0.direction == .out && !$0.isOpen }
      .sorted { ($0.closedAt ?? $0.openedAt, $0.id) > ($1.closedAt ?? $1.openedAt, $1.id) }
    byPerson = Dictionary(grouping: out, by: \.personID)
      .compactMap { id, loans in shelf.persons[id].map { PersonLoans(person: $0, loans: loans) } }
      .sorted { byName($0.person.name, $1.person.name, $0.id, $1.id) }
    borrowed = live.filter { $0.isOpen && $0.direction == .in }.sorted(by: Loan.longestOutFirst)
    overdue = out.filter { $0.isOverdue(at: now) }.count
  }

  /// The tab's badge: the overdue loans, and nothing when none is (F13: the only badge, gone when nothing is due).
  public var badge: Int? { overdue > 0 ? overdue : nil }

  /// Nothing out, nothing returned and nothing borrowed: the tab's empty state.
  public var isEmpty: Bool { out.isEmpty && returned.isEmpty && borrowed.isEmpty }
}

extension Loan {
  /// The order for "the longest out first": the oldest opening first.
  static func longestOutFirst(_ lhs: Loan, _ rhs: Loan) -> Bool { (lhs.openedAt, lhs.id) < (rhs.openedAt, rhs.id) }
}

/// Whether `lhs` sorts before `rhs` by name, ignoring case and accents, then by the exact text and the id, so the
/// order is stable.
private func byName(_ lhs: String, _ rhs: String, _ lhsID: PersonID, _ rhsID: PersonID) -> Bool {
  switch lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) {
  case .orderedAscending: true
  case .orderedDescending: false
  case .orderedSame: (lhs, lhsID) < (rhs, rhsID)
  }
}

/// One loan reminder (F13: "one reminder notification on the due date"): an open loan out with a due date that hasn't
/// passed. The client delivers it that morning and words it; this says which, for what and when.
public struct LoanReminder: Hashable, Sendable, Identifiable {
  public let id: LoanID
  public let objectID: ObjectID
  /// The object's title.
  public let title: String
  /// Who has it.
  public let person: String
  /// The due date: the day the reminder is for.
  public let at: Date
}

extension Shelf {
  /// At most this many loan reminders are pending: with the clocks' 50, within the 64 the system keeps.
  public static let loanReminderLimit = 14

  /// The reminders to schedule now: one per open loan out whose due day is today or later, soonest first, at most
  /// `loanReminderLimit`. A returned loan, one with no date and one already overdue have none: the overdue ones are
  /// on Activity's badge instead.
  public func loanReminders(at now: Date, calendar: Calendar) -> [LoanReminder] {
    let today = calendar.startOfDay(for: now)
    return
      liveLoans
      .compactMap { loan -> LoanReminder? in
        guard loan.isOpen, loan.direction == .out, let due = loan.dueAt, calendar.startOfDay(for: due) >= today,
          let object = objects[loan.objectID]
        else { return nil }
        return LoanReminder(
          id: loan.id,
          objectID: object.id,
          title: object.title,
          person: persons[loan.personID]?.name ?? "",
          at: due
        )
      }
      .sorted { ($0.at, $0.id) < ($1.at, $1.id) }
      .prefix(Self.loanReminderLimit)
      .map { $0 }
  }
}

/// What a nudge says (F13, board 21): the object, who has it, how long it's been out and how late it is. The share
/// sheet's friendly line is worded from these, and nothing else: no value, no price, nothing paid (promise 5).
public struct Nudge: Hashable, Sendable {
  public let title: String
  public let person: String
  /// Whole days since it went out.
  public let daysOut: Int
  /// Whole days past the due date; nil when it isn't overdue or has no date.
  public let daysOverdue: Int?

  public init(title: String, person: String, daysOut: Int, daysOverdue: Int?) {
    self.title = title
    self.person = person
    self.daysOut = daysOut
    self.daysOverdue = daysOverdue
  }

  /// Nil unless the loan is open and out: there's nobody to nudge about something back home or borrowed.
  public init?(loan id: LoanID, shelf: Shelf, now: Date, calendar: Calendar) {
    guard let loan = shelf.loans[id], loan.isOpen, loan.direction == .out, let object = shelf.objects[loan.objectID]
    else { return nil }
    func days(from start: Date) -> Int {
      calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: now)).day
        ?? 0
    }
    self.init(
      title: object.title,
      person: shelf.persons[loan.personID]?.name ?? "",
      daysOut: max(0, days(from: loan.openedAt)),
      daysOverdue: loan.isOverdue(at: now) ? loan.dueAt.map { max(0, days(from: $0)) } : nil
    )
  }
}

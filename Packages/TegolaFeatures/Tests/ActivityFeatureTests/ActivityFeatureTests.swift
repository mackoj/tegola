import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import ReturnFeature
import SQLiteData
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import ActivityFeature

func shelfNow() throws -> Shelf {
  @Dependency(\.defaultDatabase) var database
  return try database.read { db in try ShelfRequest().fetch(db).shelf }
}

func object(_ title: String) throws -> ObjectID {
  try #require(try shelfNow().objects.values.first { $0.title == title }?.id)
}

/// Lends Homogenic to Dara, due a week before `testNow`: one overdue loan.
func lendHomogenicOverdue() throws -> ObjectID {
  @Dependency(\.shelf) var shelf
  let id = try object("Homogenic")
  _ = try shelf.perform(.lend(id, to: .new(name: "Dara"), due: testNow - 7 * 86_400, note: "For the drive"))
  return id
}

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct ActivityFeatureTests {
  /// The seed lends Kid A to Max and borrows Root from Léa.
  @Test func itGathersLoansOutAndWhatsBorrowed() throws {
    let store = TestStore(initialState: ActivityFeature.State()) { ActivityFeature() }
    let activity = store.state.activity
    #expect(activity.out.map(\.objectID) == [try object("Kid A")])
    #expect(activity.borrowed.map(\.objectID) == [try object("Root")])
    #expect(activity.badge == nil)
  }

  /// F13: overdue first, and the badge counts it.
  @Test func anOverdueLoanLeadsAndBadgesTheTab() throws {
    let homogenic = try lendHomogenicOverdue()
    let store = TestStore(initialState: ActivityFeature.State()) { ActivityFeature() }
    #expect(store.state.activity.out.first?.objectID == homogenic)
    #expect(store.state.activity.badge == 1)
  }

  @Test func thePillsSwitchTheList() async throws {
    let store = TestStore(initialState: ActivityFeature.State()) { ActivityFeature() }
    await store.send(.view(.filterTapped(.returned))) { $0.filter = .returned }
    await store.send(.view(.filterTapped(.byPerson))) { $0.filter = .byPerson }
  }

  @Test func markReturnedOpensTheReturnSheet() async throws {
    let store = TestStore(initialState: ActivityFeature.State()) { ActivityFeature() }
    let shelf = try shelfNow()
    let loan = try #require(shelf.openLoan(on: try object("Kid A")))
    let sheet = ReturnFeature.State(loan: loan.id, shelf: shelf, now: testNow, calendar: .testUTC)
    await store.send(.view(.markReturnedTapped(loan.id))) { $0.returnLoan = sheet }
  }

  @Test func objectsAndPeopleOpenTheirPages() async throws {
    let store = TestStore(initialState: ActivityFeature.State()) { ActivityFeature() }
    let kidA = try object("Kid A")
    let max = try #require(try shelfNow().persons.values.first { $0.name == "Max" }?.id)
    await store.send(.view(.objectTapped(kidA)))
    await store.receive(\.delegate.open, .object(kidA))
    await store.send(.view(.personTapped(max)))
    await store.receive(\.delegate.open, .person(max))
  }

  /// F13: the nudge names the object and how late it is, and asks nothing more.
  @Test func theNudgeLineIsFriendly() {
    #expect(
      ActivityView.line(for: Nudge(title: "Homogenic", person: "Dara", daysOut: 21, daysOverdue: 7))
        == "Hi Dara! Just checking in on Homogenic: it was due back 7 days ago. No rush, tell me when."
    )
    #expect(
      ActivityView.line(for: Nudge(title: "Kid A", person: "Max", daysOut: 3, daysOverdue: nil))
        == "Hi Max! Hope you're enjoying Kid A. Tell me when you're done with it."
    )
    #expect(
      ActivityView.line(for: Nudge(title: "Kid A", person: "Max", daysOut: 15, daysOverdue: 1))
        == "Hi Max! Just checking in on Kid A: it was due back 1 day ago. No rush, tell me when."
    )
  }
}

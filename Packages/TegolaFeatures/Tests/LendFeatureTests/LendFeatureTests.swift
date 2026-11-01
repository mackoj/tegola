import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import LendFeature

func shelfNow() throws -> Shelf {
  @Dependency(\.defaultDatabase) var database
  return try database.read { db in try ShelfRequest().fetch(db).shelf }
}

func seeded(_ title: String) throws -> ObjectID {
  try #require(try shelfNow().objects.values.first { $0.title == title }?.id)
}

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct LendFeatureTests {
  func store(_ title: String, mode: LendFeature.State.Mode = .lend) throws -> TestStoreOf<LendFeature> {
    let id = try seeded(title)
    let state = LendFeature.State(
      objectID: id,
      title: title,
      mode: mode,
      people: try shelfNow().recentPeople,
      now: testNow
    )
    return TestStore(initialState: state) { LendFeature() } withDependencies: { $0.dismiss = DismissEffect {} }
  }

  /// F13: lend in three taps — a name, a date, Hand it over. Two weeks is the default date.
  @Test func lendingToSomeoneNewInThreeTaps() async throws {
    let store = try store("Homogenic")
    #expect(store.state.people.map(\.name) == ["Léa", "Max"])
    #expect(!store.state.canSubmit)
    await store.send(.view(.newTapped)) { $0.isNew = true }
    await store.send(.view(.newNameChanged(" Dara "))) { $0.newName = " Dara " }
    #expect(store.state.choice == .new(name: "Dara"))
    await store.send(.view(.submitTapped))
    await store.receive(\.succeeded)

    let shelf = try shelfNow()
    let loan = try #require(shelf.openLoan(on: store.state.objectID))
    #expect(shelf.persons[loan.personID]?.name == "Dara")
    #expect(loan.dueAt == Calendar.testUTC.date(byAdding: .day, value: 14, to: testNow))
    #expect(loan.note == "")
  }

  @Test func lendingToSomeoneKnownForAMonthWithANote() async throws {
    let store = try store("Homogenic")
    let max = try #require(store.state.people.first { $0.name == "Max" })
    await store.send(.view(.personTapped(max.id))) { $0.person = max.id }
    await store.send(.view(.dueTapped(.oneMonth))) { $0.due = .oneMonth }
    await store.send(.view(.noteChanged("  For the drive  "))) { $0.note = "  For the drive  " }
    await store.send(.view(.submitTapped))
    await store.receive(\.succeeded)

    let loan = try #require(try shelfNow().openLoan(on: store.state.objectID))
    #expect(loan.personID == max.id)
    #expect(loan.dueAt == Calendar.testUTC.date(byAdding: .month, value: 1, to: testNow))
    #expect(loan.note == "For the drive")
  }

  @Test func noDateIsAChoice() async throws {
    let store = try store("Homogenic")
    let lea = try #require(store.state.people.first)
    await store.send(.view(.personTapped(lea.id))) { $0.person = lea.id }
    await store.send(.view(.dueTapped(.none))) { $0.due = .none }
    await store.send(.view(.submitTapped))
    await store.receive(\.succeeded)
    #expect(try shelfNow().openLoan(on: store.state.objectID)?.dueAt == nil)
  }

  /// The rules still decide: a lent object can't be lent again, and the sheet says so instead of closing.
  @Test func aRefusalStaysOnTheSheet() async throws {
    let store = try store("Kid A")
    let lea = try #require(store.state.people.first)
    await store.send(.view(.personTapped(lea.id))) { $0.person = lea.id }
    await store.send(.view(.submitTapped))
    await store.receive(\.refused) { $0.refusal = .alreadyOnLoan }
  }

  /// PD-061: someone else's object, named as theirs.
  @Test func markingWhoseItIs() async throws {
    let id = try seeded("Root")
    let giveBack = try #require(try shelfNow().openLoan(on: id))
    @Dependency(\.shelf) var shelf
    _ = try shelf.perform(.giveBack(id))
    let store = try store("Root", mode: .borrow)
    let lea = try #require(store.state.people.first { $0.name == "Léa" })
    await store.send(.view(.personTapped(lea.id))) { $0.person = lea.id }
    await store.send(.view(.submitTapped))
    await store.receive(\.succeeded)
    let loan = try #require(try shelfNow().openLoan(on: id))
    #expect(loan.direction == .in)
    #expect(loan.id != giveBack.id)
  }
}

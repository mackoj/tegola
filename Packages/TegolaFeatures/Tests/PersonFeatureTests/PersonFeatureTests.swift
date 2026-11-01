import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import LendFeature
import SQLiteData
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import PersonFeature

func shelfNow() throws -> Shelf {
  @Dependency(\.defaultDatabase) var database
  return try database.read { db in try ShelfRequest().fetch(db).shelf }
}

func person(_ name: String) throws -> PersonID {
  try #require(try shelfNow().persons.values.first { $0.name == name }?.id)
}

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct PersonFeatureTests {
  /// The seed lends Kid A to Max with no date.
  @Test func maxsPageSaysWhatHeHolds() throws {
    let max = try person("Max")
    let store = TestStore(initialState: PersonFeature.State(id: max)) { PersonFeature() }
    let record = try #require(store.state.record)
    #expect(record.person.name == "Max")
    #expect(record.holdsNow.count == 1)
    #expect(record.lent == 1)
    #expect(record.averageDaysOut == nil)
  }

  @Test func tappingALoanOpensItsObject() async throws {
    let max = try person("Max")
    let store = TestStore(initialState: PersonFeature.State(id: max)) { PersonFeature() }
    let kidA = try #require(try shelfNow().objects.values.first { $0.title == "Kid A" }?.id)
    await store.send(.view(.loanTapped(kidA)))
    await store.receive(\.delegate.open, .object(kidA))
  }

  /// Only what can go out: owned, kept, one copy, not already lent (promise 6).
  @Test func thePickerListsOnlyWhatCanBeLent() throws {
    var state = PersonFeature.State(id: try person("Max"))
    let titles = Set(state.lendable.map(\.title))
    #expect(titles.contains("Homogenic"))
    #expect(!titles.contains("Kid A"))
    #expect(!titles.contains("Root"))
    #expect(!titles.contains("Enamel pins"))
    #expect(!titles.contains("Azul"))
    state.query = "homo"
    #expect(state.lendable.map(\.title) == ["Homogenic"])
  }

  /// Board 19: Lend them something opens the lend sheet with them already chosen; handing it over closes it all.
  @Test func lendThemSomething() async throws {
    let max = try person("Max")
    let homogenic = try #require(try shelfNow().objects.values.first { $0.title == "Homogenic" }?.id)
    let store = TestStore(initialState: PersonFeature.State(id: max)) { PersonFeature() }
    await store.send(.view(.lendSomethingTapped)) { $0.isPicking = true }
    await store.send(.view(.queryChanged("homo"))) { $0.query = "homo" }
    await store.send(.view(.objectPicked(homogenic))) {
      var sheet = LendFeature.State(
        objectID: homogenic,
        title: "Homogenic",
        mode: .lend,
        people: try shelfNow().recentPeople,
        now: testNow
      )
      sheet.person = max
      sheet.isNew = false
      $0.lend = sheet
    }
    #expect(store.state.lend?.canSubmit == true)
    await store.send(.lend(.presented(.view(.submitTapped))))
    await store.receive(\.lend.succeeded)
    await store.receive(\.lend.dismiss) {
      $0.lend = nil
      $0.isPicking = false
      $0.query = ""
    }
    #expect(try shelfNow().openLoan(on: homogenic)?.personID == max)
  }
}

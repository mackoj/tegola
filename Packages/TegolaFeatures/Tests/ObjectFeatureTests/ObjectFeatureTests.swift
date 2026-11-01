import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import LendFeature
import ObjectEditFeature
import ReturnFeature
import SQLiteData
import TegolaCatalogue
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import ObjectFeature

func seededObject(_ title: String) throws -> ObjectID {
  @Dependency(\.defaultDatabase) var database
  let shelf = try database.read { db in try ShelfRequest().fetch(db).shelf }
  return try #require(shelf.objects.values.first { $0.title == title }?.id)
}

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct ObjectFeatureTests {
  /// F4's "done when": every v1 type shows its object, with the seven slots in the product's order.
  @Test(arguments: [
    ("Radiant Silvergun", "video-game"), ("Kid A", "music"), ("Brass: Birmingham", "board-games"),
    ("Tin robot", "thing"),
  ])
  func sevenSlotsInOrderForEveryV1Type(_ title: String, _ type: String) throws {
    let id = try seededObject(title)
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    #expect(store.state.object?.typeID.rawValue == type)
    #expect(ObjectSlots.order == [.hero, .spine, .status, .signature, .fields, .actions, .history])
    #expect(store.state.history.last?.kind.name == "added")
  }

  @Test func historyIsNewestFirstAndOnlyWhatAPersonReads() throws {
    let id = try seededObject("Radiant Silvergun")
    let store = TestStore(initialState: ObjectFeature.State(id: id)) {
      ObjectFeature()
    }
    // Seeded: added, marked grail (a flag, not history), placed.
    #expect(store.state.history.map(\.kind.name) == ["placed", "added"])
  }

  @Test func mightLetGoWritesOneCommand() async throws {
    let id = try seededObject("Kid A")
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    await store.send(.view(.mightLetGoTapped))
    await store.finish()
    try await store.state.$snapshot.load()
    #expect(store.state.object?.mightLetGo == true)
  }

  @Test func aPickedPhotoIsSavedThenRecorded() async throws {
    let id = try seededObject("Kid A")
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    await store.send(.view(.photoTapped)) { $0.isPickingPhoto = true }
    await store.send(.view(.photoPicked(Data([0xFF, 0xD8])))) { $0.isPickingPhoto = false }
    await store.finish()
    try await store.state.$snapshot.load()
    let photos = store.state.snapshot.shelf.shelf.photos(of: id)
    #expect(photos.map(\.fileName) == ["photo-1.jpg"])
    #expect(store.state.history.first?.kind.name == "photo")
    @Dependency(\.photoStore) var photoStore
    #expect(photoStore.load("photo-1.jpg") == Data([0xFF, 0xD8]))
  }

  /// F15's done-when, on the object screen: watch with its reason and Estimate; the swap clears it.
  @Test func aDueBatteryShowsWatchAndLoggingASwapClearsIt() async throws {
    let id = try dueCartridge()
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    try await store.state.$snapshot.load()
    let signal = try #require(store.state.signals.first)
    #expect(signal.clock == "saveBattery")
    #expect(signal.status == .watch)
    #expect(signal.isEstimate)
    #expect(store.state.status == .watch)
    await store.send(.view(.remedyTapped(.batterySwap)))
    await store.finish()
    try await store.state.$snapshot.load()
    #expect(store.state.signals.map(\.status) == [.good])
    #expect(store.state.status == .good)
    #expect(store.state.history.first?.kind.name == "logged")
  }

  /// D-58: a tape offers a backup before its clock has anything to read; the backup starts it, and it reads good.
  @Test func aTapeOffersABackupThatStartsItsClock() async throws {
    let id = try seededObject("Nebraska")
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    try await store.state.$snapshot.load()
    #expect(store.state.signals.isEmpty)
    #expect(store.state.remedies == [.backup])
    await store.send(.view(.remedyTapped(.backup)))
    await store.finish()
    try await store.state.$snapshot.load()
    #expect(store.state.signals.map(\.status) == [.good])
    #expect(store.state.remedies.isEmpty)
  }

  @Test func dismissingHidesTheSignal() async throws {
    let id = try dueCartridge()
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    try await store.state.$snapshot.load()
    let signal = try #require(store.state.signals.first)
    await store.send(.view(.dismissTapped(signal)))
    await store.finish()
    try await store.state.$snapshot.load()
    #expect(store.state.signals.isEmpty)
    #expect(store.state.status == .fine)
  }

  @Test func editOpensTheForm() async throws {
    let id = try seededObject("Kid A")
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    let object = try #require(store.state.object)
    await store.send(.view(.editTapped)) {
      $0.destination = .edit(ObjectEditFeature.State(object: object, placePath: nil, money: .off))
    }
  }

  /// F13: Lend opens the sheet with the people most recently used first.
  @Test func lendOpensTheSheet() async throws {
    let id = try seededObject("Homogenic")
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    let people = store.state.snapshot.shelf.shelf.recentPeople
    await store.send(.view(.lendTapped)) {
      $0.destination = .lend(
        LendFeature.State(objectID: id, title: "Homogenic", mode: .lend, people: people, now: testNow)
      )
    }
  }

  @Test func markReturnedOpensTheReturnSheet() async throws {
    let id = try seededObject("Kid A")
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    let shelf = store.state.snapshot.shelf.shelf
    let loan = try #require(shelf.openLoan(on: id))
    let sheet = try #require(ReturnFeature.State(loan: loan.id, shelf: shelf, now: testNow, calendar: .testUTC))
    await store.send(.view(.returnTapped)) { $0.destination = .returnLoan(sheet) }
  }

  /// PD-061: giving someone's object back is one tap, and Activity no longer lists it.
  @Test func giveBackClosesTheBorrowing() async throws {
    let id = try seededObject("Root")
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    await store.send(.view(.giveBackTapped))
    await store.finish()
    try await store.state.$snapshot.load()
    #expect(store.state.snapshot.shelf.shelf.openLoan(on: id) == nil)
    #expect(Activity(shelf: store.state.snapshot.shelf.shelf, now: testNow).borrowed.isEmpty)
  }
}

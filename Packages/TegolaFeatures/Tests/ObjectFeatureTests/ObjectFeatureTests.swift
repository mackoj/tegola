import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import ObjectEditFeature
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

  @Test func editOpensTheForm() async throws {
    let id = try seededObject("Kid A")
    let store = TestStore(initialState: ObjectFeature.State(id: id)) { ObjectFeature() }
    let object = try #require(store.state.object)
    await store.send(.view(.editTapped)) {
      $0.edit = ObjectEditFeature.State(object: object, placePath: nil, money: .off)
    }
  }
}

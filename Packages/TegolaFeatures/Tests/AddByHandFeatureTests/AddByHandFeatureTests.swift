import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaCatalogue
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import AddByHandFeature

@MainActor
struct AddByHandHelpers {
  @Dependency(\.defaultDatabase) var database

  func shelf() throws -> ShelfSnapshot { try database.read { db in try ShelfRequest().fetch(db) } }
}

@MainActor
@Suite(.dependencies { try $0.seededShelf(seed: false) })
struct AddByHandOnAnEmptyShelfTests {
  /// F6: the first object of a type creates its collection, named by the type ("My Music", PD-137).
  @Test func firstObjectOfATypeCreatesItsCollection() async throws {
    let store = TestStore(initialState: AddByHandFeature.State()) {
      AddByHandFeature()
    } withDependencies: {
      $0.dismiss = DismissEffect {}
    }
    await store.send(.view(.typeTapped("music"))) {
      $0.type = "music"
      $0.collection = .new(name: "My Music")
    }
    await store.send(.view(.subtypeTapped("vinyl"))) { $0.subtype = "vinyl" }
    await store.send(.view(.valueChanged(.title, .text("Kid A")))) { $0.draft[.title] = .text("Kid A") }
    await store.send(.view(.saveTapped(addAnother: false)))
    await store.receive(\.saveSucceeded) { $0.added = 1 }
    await store.receive(\.delegate.added)
    let snapshot = try AddByHandHelpers().shelf()
    #expect(snapshot.shelf.collections.values.map(\.name) == ["My Music"])
    #expect(snapshot.shelf.objects.values.first?.subtype == "vinyl")
    #expect(snapshot.shelf.objects.values.first?.identity == .confirmed)
  }
}

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct AddByHandFeatureTests {
  /// F6: Add to defaults to the last-used collection, when it takes the type.
  @Test func addToDefaultsToTheLastUsedCollection() async throws {
    let snapshot = try AddByHandHelpers().shelf()
    let things = try #require(snapshot.shelf.collections.values.first { $0.name == "Things" })
    let library = try #require(snapshot.shelf.collections.values.first { $0.name == "The Library" })
    let store = TestStore(initialState: AddByHandFeature.State()) {
      AddByHandFeature()
    } withDependencies: {
      $0.dismiss = DismissEffect {}
    }
    // No collection used yet: a game goes to the games collection.
    await store.send(.view(.typeTapped("video-game"))) {
      $0.type = "video-game"
      $0.collection = .existing(library.id)
    }
    await store.send(.view(.typeTapped("thing"))) {
      $0.type = "thing"
      $0.collection = .existing(things.id)
    }
    await store.send(.view(.valueChanged(.title, .text("Tin rocket")))) { $0.draft[.title] = .text("Tin rocket") }
    await store.send(.view(.saveTapped(addAnother: true)))
    await store.receive(\.saveSucceeded) {
      $0.added = 1
      $0.draft = [:]
    }
    try await store.state.$snapshot.load()
    #expect(store.state.snapshot.lastCollection == things.id)
    // The next sheet points at the collection used last.
    let next = TestStore(initialState: AddByHandFeature.State()) { AddByHandFeature() }
    try await next.state.$snapshot.load()
    await next.send(.view(.typeTapped("thing"))) {
      $0.type = "thing"
      $0.collection = .existing(things.id)
    }
  }

  /// Review of M3, finding 11: last-used wins over the type's own collection, here a mixed one.
  @Test func aMixedCollectionUsedLastWinsOverTheTypesOwn() async throws {
    @Dependency(\.shelf) var shelf
    @Dependency(\.settings) var settings
    let mixed = try #require(
      try shelf.perform(.createCollection(name: "Everything", type: nil)).createdCollections.first
    )
    try settings.set(.lastCollection, mixed.rawValue.uuidString)
    let store = TestStore(initialState: AddByHandFeature.State()) { AddByHandFeature() }
    try await store.state.$snapshot.load()
    await store.send(.view(.typeTapped("thing"))) {
      $0.type = "thing"
      $0.collection = .existing(mixed)
    }
  }

  @Test func saveAndAddAnotherKeepsTheTypeSubtypeAndCollection() async throws {
    let store = TestStore(initialState: AddByHandFeature.State()) { AddByHandFeature() }
    let library = try #require(store.state.snapshot.shelf.collections.values.first { $0.name == "The Library" })
    await store.send(.view(.typeTapped("video-game"))) {
      $0.type = "video-game"
      $0.collection = .existing(library.id)
    }
    await store.send(.view(.subtypeTapped("n64"))) { $0.subtype = "n64" }
    for (index, title) in ["Mario Kart 64", "GoldenEye 007", "Banjo-Kazooie"].enumerated() {
      await store.send(.view(.valueChanged(.title, .text(title)))) { $0.draft[.title] = .text(title) }
      await store.send(.view(.saveTapped(addAnother: true)))
      await store.receive(\.saveSucceeded) {
        $0.added = index + 1
        $0.draft = [:]
      }
    }
    #expect(store.state.subtype == "n64")
    let objects = try AddByHandHelpers().shelf().shelf.objects.values.filter { $0.subtype == "n64" }
    #expect(objects.count == 4)
    #expect(objects.allSatisfy { $0.values[.field("media")] == .text("Cartridge") })
  }

  @Test func aTitleIsNeeded() async {
    let store = TestStore(initialState: AddByHandFeature.State()) { AddByHandFeature() }
    #expect(!store.state.canSave)
  }
}

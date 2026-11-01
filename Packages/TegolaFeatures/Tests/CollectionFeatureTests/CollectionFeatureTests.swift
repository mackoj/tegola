import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import CollectionFeature

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct CollectionFeatureTests {
  func collection(named name: String) throws -> CollectionID {
    @Dependency(\.defaultDatabase) var database
    let shelf = try database.read { db in try ShelfRequest().fetch(db).shelf }
    return try #require(shelf.collections.values.first { $0.name == name }?.id)
  }

  @Test func rowsSortByRecentTitleAndYear() async throws {
    let id = try collection(named: "My Music")
    let store = TestStore(initialState: CollectionFeature.State(id: id)) {
      CollectionFeature()
    }
    #expect(store.state.objects.map(\.title) == ["Selected Ambient Works", "Nebraska", "Homogenic", "Kid A"])
    await store.send(.view(.sortTapped(.title))) { $0.sort = .title }
    #expect(store.state.objects.map(\.title) == ["Homogenic", "Kid A", "Nebraska", "Selected Ambient Works"])
  }

  /// The status filter (D-59): a due cartridge is the collection's only *watch*.
  @Test func rowsFilterByStatus() async throws {
    let due = try dueCartridge()
    let id = try collection(named: "The Library")
    let store = TestStore(initialState: CollectionFeature.State(id: id)) { CollectionFeature() }
    try await store.state.$snapshot.load()
    #expect(store.state.statusChoices == [.watch, .good])
    await store.send(.view(.statusTapped(.watch))) { $0.status = .watch }
    #expect(store.state.objects.map(\.id) == [due])
    // Review of M4, finding 4: once nothing is watch any more, the chosen filter stays, so it can be cleared.
    @Dependency(\.shelf) var shelf
    _ = try shelf.perform(.logEvent(due, kind: ShelfEvent.Kind.servicedKind, note: ""))
    try await store.state.$snapshot.load()
    #expect(store.state.objects.isEmpty)
    #expect(store.state.statusChoices.contains(.watch))
    await store.send(.view(.statusTapped(nil))) { $0.status = nil }
    #expect(store.state.objects.count > 1)
  }

  @Test func letGoObjectsLeaveTheList() async throws {
    let id = try collection(named: "Board games")
    let store = TestStore(initialState: CollectionFeature.State(id: id)) {
      CollectionFeature()
    }
    // Azul was let go in the seed; Brass and the borrowed Root remain.
    #expect(store.state.objects.map(\.title).sorted() == ["Brass: Birmingham", "Root"])
  }

  @Test func filteringByAPlaceIncludesWhatsInsideIt() async throws {
    let id = try collection(named: "The Library")
    let store = TestStore(initialState: CollectionFeature.State(id: id)) {
      CollectionFeature()
    }
    let office = try #require(store.state.snapshot.shelf.places.values.first { $0.name == "Office" })
    #expect(store.state.placeChoices.count == 2)
    await store.send(.view(.placeTapped(office.id))) { $0.place = office.id }
    #expect(store.state.objects.map(\.title).sorted() == ["Pokémon Red", "Radiant Silvergun"])
  }

  @Test func renameCancelWritesNothingAndSaveWritesOneCommand() async throws {
    let id = try collection(named: "My Music")
    let store = TestStore(initialState: CollectionFeature.State(id: id)) { CollectionFeature() }
    await store.send(.view(.renameTapped)) { $0.renameDraft = "My Music" }
    await store.send(.view(.renameChanged("Records"))) { $0.renameDraft = "Records" }
    await store.send(.view(.renameCancelTapped)) { $0.renameDraft = nil }
    #expect(store.state.collection?.name == "My Music")
    await store.send(.view(.renameTapped)) { $0.renameDraft = "My Music" }
    await store.send(.view(.renameChanged("Records"))) { $0.renameDraft = "Records" }
    await store.send(.view(.renameSaveTapped)) { $0.renameDraft = nil }
    await store.finish()
    try await store.state.$snapshot.load()
    #expect(store.state.collection?.name == "Records")
  }

  @Test func aRowOpensItsObject() async throws {
    let id = try collection(named: "My Music")
    let store = TestStore(initialState: CollectionFeature.State(id: id)) {
      CollectionFeature()
    }
    let object = try #require(store.state.objects.first)
    await store.send(.view(.objectTapped(object.id)))
    await store.receive(\.delegate.open, Route.object(object.id))
  }
}

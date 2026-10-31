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

@testable import PlacesFeature

@MainActor
@Suite(.dependencies { try $0.seededShelf(seed: false) })
struct PlacesFeatureTests {
  @Dependency(\.shelf) var shelf
  @Dependency(\.defaultDatabase) var database

  func snapshot() throws -> ShelfSnapshot { try database.read { db in try ShelfRequest().fetch(db) } }

  func add(_ title: String, at place: String) throws {
    let receipt = try shelf.perform(
      .add(
        ObjectDraft(type: "board-games", values: [.title: .text(title)]),
        to: .new(name: "Board games"),
        origin: .typed
      )
    )
    _ = try shelf.perform(.setPlace(receipt.createdObjects, PlacePath(typed: place)))
  }

  /// F10's done-when: the Places screen appears only once two places exist.
  @Test func screenAppearsOnlyOnceTwoPlacesExist() throws {
    #expect(!ShelfSummary(shelf: try snapshot().shelf, money: .off, now: testNow).showsPlaces)
    try add("Brass", at: "Attic")
    #expect(!ShelfSummary(shelf: try snapshot().shelf, money: .off, now: testNow).showsPlaces)
    try add("Root", at: "Living room")
    #expect(ShelfSummary(shelf: try snapshot().shelf, money: .off, now: testNow).showsPlaces)
  }

  @Test func aNearDuplicateMergesInOneTap() async throws {
    try add("Brass", at: "Living room")
    try add("Root", at: "Livng room")
    let store = TestStore(initialState: PlacesFeature.State()) { PlacesFeature() }
    try await store.state.$snapshot.load()
    let (kept, typo) = try #require(store.state.snapshot.shelf.nearDuplicatePlaces().first)
    await store.send(.view(.mergeTapped(typo.id, into: kept.id)))
    await store.finish()
    let shelf = try snapshot().shelf
    #expect(shelf.livePlaces.map(\.name) == ["Living room"])
    #expect(shelf.objects.values.allSatisfy { $0.placeID == kept.id })
  }

  @Test func aPlaceListsWhatsInItAndInsideIt() async throws {
    try add("Brass", at: "Office")
    try add("Root", at: "Office › Shelf 2")
    let office = try #require(try snapshot().shelf.livePlaces.first { $0.name == "Office" })
    let store = TestStore(initialState: PlaceFeature.State(id: office.id)) { PlaceFeature() }
    try await store.state.$snapshot.load()
    #expect(store.state.objects.map(\.title) == ["Brass", "Root"])
    #expect(store.state.children.map(\.name) == ["Shelf 2"])
    await store.send(.view(.placeTapped(store.state.children[0].id)))
    await store.receive(\.delegate.open, .place(store.state.children[0].id))
  }
}

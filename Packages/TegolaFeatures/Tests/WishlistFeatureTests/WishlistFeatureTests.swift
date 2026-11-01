import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import WishlistFeature

func shelfNow() throws -> Shelf {
  @Dependency(\.defaultDatabase) var database
  return try database.read { db in try ShelfRequest().fetch(db).shelf }
}

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct WishlistFeatureTests {
  func policenauts() throws -> ObjectID {
    try #require(try shelfNow().objects.values.first { $0.title == "Policenauts" }?.id)
  }

  @Test func itListsTheSeedsWants() throws {
    let store = TestStore(initialState: WishlistFeature.State()) { WishlistFeature() }
    #expect(store.state.wishlist.wants.map(\.object.title).contains("Policenauts"))
    #expect(store.state.wishlist.wants.allSatisfy { $0.object.ownership == .wanted })
  }

  /// F16: It arrived flips ownership; the object leaves the wishlist and keeps its history.
  @Test func itArrived() async throws {
    let id = try policenauts()
    let store = TestStore(initialState: WishlistFeature.State()) { WishlistFeature() }
    await store.send(.view(.arrivedTapped(id)))
    await store.finish()
    #expect(try shelfNow().objects[id]?.ownership == .owned)
    try await store.state.$snapshot.load()
    #expect(!store.state.wishlist.wants.contains { $0.id == id })
  }

  @Test func grailTogglesAndLeadsTheList() async throws {
    let id = try policenauts()
    let store = TestStore(initialState: WishlistFeature.State()) { WishlistFeature() }
    let before = try #require(try shelfNow().objects[id]?.isGrail)
    await store.send(.view(.grailTapped(id)))
    await store.finish()
    #expect(try shelfNow().objects[id]?.isGrail == !before)
  }

  @Test func aWantOpensItsObject() async throws {
    let id = try policenauts()
    let store = TestStore(initialState: WishlistFeature.State()) { WishlistFeature() }
    await store.send(.view(.wantTapped(id)))
    await store.receive(\.delegate.open, .object(id))
  }
}

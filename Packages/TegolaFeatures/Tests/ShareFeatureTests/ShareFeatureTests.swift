import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import ShareFeature

func shelfNow() throws -> Shelf {
  @Dependency(\.defaultDatabase) var database
  return try database.read { db in try ShelfRequest().fetch(db).shelf }
}

func object(_ title: String) throws -> ObjectID {
  try #require(try shelfNow().objects.values.first { $0.title == title }?.id)
}

/// Gives Radiant Silvergun a paid figure, the one thing no card may carry.
func paySilvergun() throws -> ObjectID {
  @Dependency(\.shelf) var shelf
  let id = try object("Radiant Silvergun")
  let paid = Money(minorUnits: 12_000, currency: Currency("EUR")!)
  _ = try shelf.perform(.edit(id, values: [.paid: .money(paid), .value: .money(paid)]))
  return id
}

func moneyOn() throws {
  @Dependency(\.defaultDatabase) var database
  @Dependency(\.catalogue) var catalogue
  try ShelfStore(migrated: database, catalogue: catalogue).set(.money, to: "on")
}

@MainActor
@Suite(.dependencies {
  try $0.seededShelf()
  $0.locale = Locale(identifier: "fr_FR")
})
struct ShareFeatureTests {
  @Test func theRecordIsTheDefaultAndCarriesNoMoney() throws {
    let id = try paySilvergun()
    try moneyOn()
    let store = TestStore(initialState: ShareFeature.State(objectID: id)) { ShareFeature() }
    let card = try #require(store.state.card)
    #expect(card.kind == .record)
    #expect(card.facts.map(\.key).contains(.field("publisher")))
    #expect(!card.facts.contains { if case .money = $0.value { true } else { false } })
    #expect(!store.state.asksForPrice)
  }

  /// F14: my copy carries an asking price only with money on, and never what was paid.
  @Test func myCopyAsksForAPriceOnlyWithMoneyOn() async throws {
    let id = try paySilvergun()
    let store = TestStore(initialState: ShareFeature.State(objectID: id)) { ShareFeature() }
    await store.send(.view(.kindTapped(.myCopy))) { $0.kind = .myCopy }
    #expect(!store.state.asksForPrice)
    await store.send(.view(.askingChanged(150))) { $0.asking = 150 }
    #expect(store.state.card?.askingPrice == nil)

    try moneyOn()
    try await store.state.$snapshot.load()
    #expect(store.state.asksForPrice)
    let card = try #require(store.state.card)
    #expect(card.askingPrice?.minorUnits == 15_000)
    #expect(card.facts.map(\.key).contains(.axis("boxCondition")))
    #expect(!card.facts.contains { if case .money = $0.value { true } else { false } })
  }

  /// Someone else's object has no "my copy" to share.
  @Test func aBorrowedObjectSharesOnlyItsRecord() async throws {
    let root = try object("Root")
    let store = TestStore(initialState: ShareFeature.State(objectID: root)) { ShareFeature() }
    #expect(!store.state.offersMyCopy)
    await store.send(.view(.kindTapped(.myCopy)))
    #expect(store.state.kind == .record)
  }
}

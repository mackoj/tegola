import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import TegolaCatalogue
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@Suite(
  .dependencies {
    $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
    $0.uuid = .incrementing
    try $0.bootstrapDatabase()
    $0.shelf = .store(ShelfStore(migrated: $0.defaultDatabase, catalogue: try Catalogue.bundled()))
  }
)
struct ShelfClientTests {
  @Test func theTestValueIsUnimplemented() {
    withDependencies {
      $0.shelf = ShelfClient.testValue
    } operation: {
      @Dependency(\.shelf) var shelf
      withKnownIssue {
        _ = try shelf.perform(.confirm([]))
      }
    }
  }

  /// The live client writes through the store, with the time and ids from dependencies.
  @Test func theLiveClientPerformsThroughTheStore() throws {
    @Dependency(\.shelf) var shelf
    let receipt = try shelf.perform(
      .add(
        ObjectDraft(type: "board-games", values: [.title: .text("Brass")]),
        to: .new(name: "Board games"),
        origin: .typed
      )
    )
    #expect(receipt.events.map(\.kind.name) == ["collectionCreated", "added"])
    #expect(receipt.events.allSatisfy { $0.at == Date(timeIntervalSince1970: 1_800_000_000) })
    // Ids come from the uuid dependency: the collection takes the first, its event the next.
    #expect(receipt.createdCollections.first?.rawValue == UUID(0))
    #expect(receipt.events.first?.id.rawValue == UUID(1))
  }

  @Test func aRefusalReachesTheFeature() throws {
    @Dependency(\.shelf) var shelf
    #expect(throws: ShelfRuleViolation.emptyTitle) {
      try shelf.perform(.add(ObjectDraft(type: "thing"), to: .new(name: "Things"), origin: .typed))
    }
  }
}

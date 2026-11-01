import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaCatalogue
import TegolaClients
import TegolaFixtures
import TegolaInterchange
import TegolaModel
import TegolaStorage
import Testing

@testable import ImportFeature

@MainActor
func store() throws -> ShelfStore {
  @Dependency(\.defaultDatabase) var database
  @Dependency(\.catalogue) var catalogue
  return ShelfStore(migrated: database, catalogue: catalogue)
}

/// T6.10 over the real `Jeux collection.csv` (M6's exit test stand-in, PLAN F9).
@MainActor
@Suite(
  .dependencies {
    try $0.seededShelf(seed: false)
    $0.lookupQueue = .store(ShelfStore(migrated: $0.defaultDatabase, catalogue: $0.catalogue))
  }
)
struct ImportFeatureTests {
  func read(_ test: TestStoreOf<ImportFeature>) async throws {
    let data = try Fixture.jeuxCollection.data()
    await test.send(.view(.fileChosen(name: "Jeux collection.csv", data: data)))
    await test.receive(\.planned, timeout: .seconds(30))
  }

  /// The one sentence, renamed, built in one write; every row unconfirmed; matched rows wait for Review.
  @Test func jeuxBecomesOneCollectionAndItsMatchesWaitForReview() async throws {
    let tetris = LookupCandidate(
      releaseID: "igdb:tetris",
      type: "video-game",
      values: [.title: .text("Tetris")],
      confidence: 0.95,
      reasons: [.title],
      sources: [.init(name: "IGDB")]
    )
    let test = TestStore(initialState: ImportFeature.State()) {
      ImportFeature()
    } withDependencies: {
      // The server knows Tetris, and nothing else.
      $0.lookup.match = { _, rows in
        Dictionary(
          uniqueKeysWithValues: rows.map { ($0.ref, $0.title.hasPrefix("Tetris") ? .matched(tetris) : .unknown) }
        )
      }
    }
    test.exhaustivity = .off
    try await read(test)
    #expect(test.state.step == .sentence)
    #expect(test.state.plan?.rows.count == 485)
    #expect(test.state.collectionName == "Jeux")
    #expect(test.state.importers.first == "spreadsheet")

    await test.send(.view(.renamed("Mes jeux")))
    await test.send(.view(.buildTapped))
    await test.receive(\.built, timeout: .seconds(30))
    // Matching is handed to the app, so closing the sheet doesn't stop it (D-74).
    await test.receive(\.delegate.match, timeout: .seconds(30))
    let plan = try #require(test.state.plan)
    let objects = test.state.objects
    let matched = try await withDependencies {
      $0.lookup.match = { _, rows in
        Dictionary(
          uniqueKeysWithValues: rows.map { ($0.ref, $0.title.hasPrefix("Tetris") ? .matched(tetris) : .unknown) }
        )
      }
    } operation: {
      try await ImportFeature.match(plan.rows, objects: objects)
    }

    let shelf = try store().shelf()
    #expect(shelf.collections.values.map(\.name) == ["Mes jeux"])
    #expect(shelf.objects.count == 485)
    #expect(shelf.objects.values.allSatisfy { $0.identity == .unconfirmed })
    let answered = try store().lookupQueue().requests.filter { $0.state == .answered }
    #expect(!answered.isEmpty && answered.count == matched)
    #expect(answered.allSatisfy { $0.answer == [tetris] })
  }

  /// Undo removes the rows nobody touched, keeps the rest, and says so (PD-047, D-64).
  @Test func undoRemovesWhatNobodyTouched() async throws {
    let test = TestStore(initialState: ImportFeature.State()) {
      ImportFeature()
    } withDependencies: {
      $0.lookup.match = { _, _ in throw LookupFailure.unavailable }
    }
    test.exhaustivity = .off
    try await read(test)
    await test.send(.view(.buildTapped))
    await test.receive(\.built, timeout: .seconds(30))
    // The collector changes one row.
    @Dependency(\.shelf) var shelf
    let touched = try #require(test.state.objects.first)
    _ = try shelf.perform(.setGrail(touched, true))

    await test.send(.view(.undoTapped))
    await test.receive(\.undone, timeout: .seconds(30))
    // Undo runs once: another tap does nothing.
    await test.send(.view(.undoTapped))
    #expect(test.state.undone == .init(removed: 484, kept: 1))
    #expect(try store().shelf().objects.keys.sorted() == [touched])
  }

  /// A file nothing can read goes back to the picker and says so.
  @Test func anUnreadableFileSaysSo() async throws {
    let test = TestStore(initialState: ImportFeature.State()) { ImportFeature() }
    test.exhaustivity = .off
    await test.send(.view(.fileChosen(name: "empty.csv", data: Data())))
    await withKnownIssue(isIntermittent: true) {
      await test.receive(\.planFailed)
    }
    #expect(test.state.step == .pick && test.state.failed)
  }
}

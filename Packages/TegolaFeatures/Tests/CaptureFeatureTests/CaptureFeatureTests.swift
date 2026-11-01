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

@testable import CaptureFeature

let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

let tetris = LookupCandidate(
  releaseID: "igdb:tetris-gb",
  type: "video-game",
  subtype: "game-boy",
  values: [.title: .text("Tetris")],
  confidence: 0.94,
  reasons: [.image, .ocr],
  sources: [.init(name: "IGDB")]
)

@MainActor
func store() throws -> ShelfStore {
  @Dependency(\.defaultDatabase) var database
  @Dependency(\.catalogue) var catalogue
  return ShelfStore(migrated: database, catalogue: catalogue)
}

/// T6.9 (PLAN F6): a shot saves before any network, the camera stays open, and Identify is one shot's.
@MainActor
@Suite(
  .dependencies {
    try $0.seededShelf()
    let store = ShelfStore(migrated: $0.defaultDatabase, catalogue: $0.catalogue)
    $0.lookupQueue = .store(store)
  }
)
struct CaptureFeatureTests {
  func ready() async throws -> TestStoreOf<CaptureFeature> {
    let test = TestStore(initialState: CaptureFeature.State()) { CaptureFeature() }
    test.exhaustivity = .off
    await test.send(.view(.typeTapped("video-game")))
    return test
  }

  /// The object is saved, unidentified, with its barcode queued in the same write; the tray shows it.
  @Test func aShotSavesBeforeAnyNetwork() async throws {
    let test = try await ready()
    let before = try store().shelf().objects.count
    await test.send(.view(.recognised(.barcode("045496730437")))) { $0.seen = .barcode("045496730437") }
    await test.send(.view(.shutterTapped(photo: jpeg)))
    await test.receive(\.saved)
    await test.receive(\.delegate.queued)

    let shelf = try store().shelf()
    #expect(shelf.objects.count == before + 1)
    let item = try #require(test.state.tray.first)
    #expect(item.status == .queued)
    let object = try #require(shelf.objects[item.id])
    #expect(object.identity == .needsDetails)
    #expect(shelf.collections[object.collectionID]?.name == "The Library")
    let request = try #require(try store().lookupQueue().requests.first { $0.objectID == item.id })
    #expect(request.identifier == .barcode("045496730437"))
    #expect(request.state == .waiting)
    #expect(try store().history(of: item.id).contains { if case .photoAttached = $0.kind { true } else { false } })
  }

  /// Identify sends this shot's photo with what was read, keeps the answer for the review queue, and is off again.
  @Test func identifyIsOneShots() async throws {
    let sent = LockIsolated<(LookupHints, Data?)?>(nil)
    let test = try await withDependencies {
      $0.lookup.identify = { _, hints, photo in
        sent.setValue((hints, photo))
        return [tetris]
      }
    } operation: {
      try await ready()
    }
    await test.send(.view(.recognised(.text("TETRIS\nNintendo"))))
    await test.send(.view(.identifyToggled(true))) { $0.identify = true }
    await test.send(.view(.shutterTapped(photo: jpeg))) { $0.identify = false }
    await test.receive(\.saved)
    await test.receive(\.identified)
    // What was read went out with the photo, not again through the worker.

    #expect(sent.value?.0 == LookupHints(text: "TETRIS\nNintendo"))
    #expect(sent.value?.1 == jpeg)
    let item = try #require(test.state.tray.first)
    #expect(item.status == .proposed("Tetris"))
    let request = try #require(try store().lookupQueue().requests.first { $0.objectID == item.id })
    #expect(request.state == .answered && request.answer == [tetris])
  }

  /// Offline, Identify fails and what was read waits in the queue; the photo is never queued (D-71).
  @Test func identifyOfflineLeavesTheReadingQueued() async throws {
    let test = try await withDependencies {
      $0.lookup.identify = { _, _, _ in throw LookupFailure.unavailable }
    } operation: {
      try await ready()
    }
    await test.send(.view(.recognised(.barcode("045496730437"))))
    await test.send(.view(.identifyToggled(true)))
    await test.send(.view(.shutterTapped(photo: jpeg)))
    await test.receive(\.saved)
    await test.receive(\.identified)

    let item = try #require(test.state.tray.first)
    #expect(item.status == .queued)
    let request = try #require(try store().lookupQueue().requests.first { $0.objectID == item.id })
    #expect(request.state == .waiting && request.identifier == .barcode("045496730437"))
  }

  /// A shot with nothing read still keeps Identify's answer, as an answered request that's never sent.
  @Test func identifyWithNothingReadKeepsItsAnswer() async throws {
    let test = try await withDependencies {
      $0.lookup.identify = { _, _, _ in [tetris] }
    } operation: {
      try await ready()
    }
    await test.send(.view(.identifyToggled(true)))
    await test.send(.view(.shutterTapped(photo: jpeg)))
    await test.receive(\.saved)
    await test.receive(\.identified)

    let item = try #require(test.state.tray.first)
    let requests = try store().lookupQueue().requests.filter { $0.objectID == item.id }
    #expect(requests.map(\.state) == [.answered])
    #expect(requests.first?.answer == [tetris])
  }

  /// No type picked yet: the shutter does nothing.
  @Test func nothingIsSavedWithoutAddTo() async throws {
    let test = TestStore(initialState: CaptureFeature.State()) { CaptureFeature() }
    await test.send(.view(.shutterTapped(photo: jpeg)))
  }
}

/// F6's done-when on an empty shelf: the first shot of a type makes its collection, and the next shots go into it.
@MainActor
@Suite(
  .dependencies {
    try $0.seededShelf(seed: false)
    $0.lookupQueue = .store(ShelfStore(migrated: $0.defaultDatabase, catalogue: $0.catalogue))
  }
)
struct CaptureOnAnEmptyShelfTests {
  @Test func theFirstShotMakesTheCollectionAndTheNextGoInIt() async throws {
    let test = TestStore(initialState: CaptureFeature.State()) { CaptureFeature() }
    test.exhaustivity = .off
    await test.send(.view(.typeTapped("music"))) { $0.collection = .new(name: "My Music") }
    await test.send(.view(.shutterTapped(photo: nil)))
    await test.receive(\.saved)
    await test.send(.view(.shutterTapped(photo: nil)))
    await test.receive(\.saved)

    let shelf = try store().shelf()
    #expect(shelf.collections.values.map(\.name) == ["My Music"])
    #expect(shelf.objects.count == 2)
    #expect(try store().lookupQueue().requests.isEmpty)
  }
}

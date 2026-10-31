import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaModel
import TegolaStorage
import Testing

@testable import ObjectEditFeature

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct ObjectEditFeatureTests {
  @Dependency(\.defaultDatabase) var database

  func object(_ title: String) throws -> ShelfObject {
    let shelf = try database.read { db in try ShelfRequest().fetch(db).shelf }
    return try #require(shelf.objects.values.first { $0.title == title })
  }

  func history(_ id: ObjectID) throws -> [ShelfEvent] {
    try database.read { db in try ObjectRequest(id: id).fetch(db).history }
  }

  /// F5: Cancel writes nothing.
  @Test func cancelLeavesTheObjectUntouched() async throws {
    let before = try object("Radiant Silvergun")
    let events = try history(before.id).count
    let store = TestStore(initialState: ObjectEditFeature.State(object: before, placePath: nil, money: .off)) {
      ObjectEditFeature()
    } withDependencies: {
      $0.dismiss = DismissEffect {}
    }
    await store.send(.view(.valueChanged(.field("publisher"), .text("ESP")))) {
      $0.draft[.field("publisher")] = .text("ESP")
    }
    await store.send(.view(.cancelTapped))
    #expect(try object("Radiant Silvergun") == before)
    #expect(try history(before.id).count == events)
  }

  /// F5: Save writes one history event that names exactly the changed keys.
  @Test func saveAppendsOneHistoryEvent() async throws {
    let before = try object("Radiant Silvergun")
    let events = try history(before.id).count
    let store = TestStore(initialState: ObjectEditFeature.State(object: before, placePath: nil, money: .off)) {
      ObjectEditFeature()
    } withDependencies: {
      $0.dismiss = DismissEffect {}
    }
    await store.send(.view(.valueChanged(.field("publisher"), .text("ESP")))) {
      $0.draft[.field("publisher")] = .text("ESP")
    }
    await store.send(.view(.valueChanged(.axis("manualCondition"), .text("Very good")))) {
      $0.draft[.axis("manualCondition")] = .text("Very good")
    }
    // Typing a value back to what it was is no change.
    await store.send(.view(.valueChanged(.title, .text("Radiant Silvergun"))))
    await store.send(.view(.saveTapped))
    await store.receive(\.saveSucceeded)
    let after = try history(before.id)
    #expect(after.count == events + 1)
    let changes: [FieldKey: FieldValue?] = [
      .field("publisher"): .text("ESP"), .axis("manualCondition"): .text("Very good"),
    ]
    let expected = ShelfEvent.Kind.edited(before.id, changes: changes)
    #expect(after.last?.kind == expected)
  }

  @Test func aNewPlaceIsItsOwnHistoryLine() async throws {
    let before = try object("Kid A")
    let store = TestStore(initialState: ObjectEditFeature.State(object: before, placePath: nil, money: .off)) {
      ObjectEditFeature()
    } withDependencies: {
      $0.dismiss = DismissEffect {}
    }
    await store.send(.view(.placeChanged("Living room › Record shelf"))) { $0.place = "Living room › Record shelf" }
    await store.send(.view(.saveTapped))
    await store.receive(\.saveSucceeded)
    #expect(try history(before.id).last?.kind.name == "placed")
  }

  @Test func aRefusedSaveSaysWhyAndStaysOpen() async throws {
    let wanted = try object("Policenauts")
    let store = TestStore(initialState: ObjectEditFeature.State(object: wanted, placePath: nil, money: .off)) {
      ObjectEditFeature()
    }
    await store.send(.view(.valueChanged(.axis("boxCondition"), .text("Good")))) {
      $0.draft[.axis("boxCondition")] = .text("Good")
    }
    await store.send(.view(.saveTapped))
    await store.receive(\.saveRefused) { $0.refusal = .wantedHasNoCondition }
  }

  @Test func autoStaysUntilTheFormChangesIt() throws {
    var object = try object("Kid A")
    object.auto = [.subtitle]
    let state = ObjectEditFeature.State(object: object, placePath: nil, money: .off)
    #expect(state.auto == [.subtitle])
    #expect(state.changes.isEmpty)
  }
}

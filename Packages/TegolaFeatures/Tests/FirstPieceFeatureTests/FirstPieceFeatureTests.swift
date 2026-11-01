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

@testable import FirstPieceFeature

@MainActor
func shelfNow() throws -> ShelfSnapshot {
  @Dependency(\.defaultDatabase) var database
  return try database.read { db in try ShelfRequest().fetch(db) }
}

let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

/// PLAN F2's done-when: a named piece lands on the shelf in a collection the collector never created, with its story
/// as the first history event and no acquired date, and a piece of a type that isn't enabled is saved as a Thing with
/// the tester offer.
@MainActor
@Suite(.dependencies { try $0.seededShelf(seed: false) })
struct FirstPieceFeatureTests {
  /// The photo path, recognised: 46's Ocarina of Time.
  @Test func aRecognisedPhotoLandsInTheCollectionItsTypeNames() async throws {
    let store = TestStore(initialState: FirstPieceFeature.State()) {
      FirstPieceFeature()
    } withDependencies: {
      $0.extraction.describePhoto = { _ in
        PieceDescription(name: "Ocarina of Time", words: ["Nintendo 64", "game cartridge"], year: 1998)
      }
    }
    await store.send(.view(.photoTaken(jpeg))) {
      $0.photo = jpeg
      $0.step = .reading
    }
    await store.receive(\.described) {
      $0.name = "Ocarina of Time"
      $0.year = 1998
      $0.words = ["Nintendo 64", "game cartridge"]
      $0.guess = TypeGuess(type: "video-game", subtype: "n64", isEnabled: true)
      $0.type = "video-game"
      $0.subtype = "n64"
      $0.step = .recognised
    }
    await store.send(.view(.thatsItTapped)) { $0.step = .story }
    await store.send(.view(.chipTapped(.sinceChild))) { $0.chip = .sinceChild }
    await store.send(.view(.lineChanged("  my brother's, then mine "))) { $0.line = "  my brother's, then mine " }
    await store.send(.view(.saveTapped)) { $0.isSaving = true }
    await store.receive(\.saved) {
      $0.isSaving = false
      $0.saved = try #require(try shelfNow().shelf.objects.keys.first)
      // 46: "Your save is at risk. The cart's CR2032 has been running since 1998."
      $0.payoff = FirstPiecePayoff(
        line: .now(
          Signal(
            clock: "saveBattery",
            status: .watch,
            reason: .battery(since: 1998, swapped: false, lastsYears: 25...35),
            changesAt: Calendar.testUTC.date(from: DateComponents(year: 2033, month: 1, day: 1))
          )
        )
      )
      $0.step = .payoff
    }

    let snapshot = try shelfNow()
    let piece = try #require(snapshot.shelf.objects.values.first)
    #expect(snapshot.shelf.objects.count == 1)
    #expect(snapshot.shelf.collections.values.map(\.name) == ["The Library"])
    #expect(piece.title == "Ocarina of Time")
    #expect(piece.subtype == "n64")
    #expect(piece.values[.year] == .year(1998))
    #expect(piece.values[.acquired] == nil)
    let events = try ShelfEvents.all()
    let story = events.compactMap { event -> String? in
      if case .added(_, .firstPiece(let story)) = event.kind { story } else { nil }
    }
    #expect(story == ["Had it since I was a kid · my brother's, then mine"])
    // The story is the first line of the piece's history.
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.catalogue) var catalogue
    let history = try ShelfStore(migrated: database, catalogue: catalogue).history(of: piece.id)
    guard case .added(_, .firstPiece) = history.first?.kind else {
      Issue.record("the first history line isn't the story: \(String(describing: history.first))")
      return
    }
    #expect(events.contains { if case .photoAttached = $0.kind { true } else { false } })
  }

  /// 46, 2B: "Watches aren't a full type yet. It's saved safely as a Thing." Count me in makes the collector a tester.
  @Test func aTypeThatHasntShippedIsAThingAndCountMeInRecordsATester() async throws {
    let store = TestStore(initialState: FirstPieceFeature.State()) {
      FirstPieceFeature()
    } withDependencies: {
      $0.extraction.describePhoto = { _ in PieceDescription(name: "Omega Seamaster", words: ["wristwatch"]) }
    }
    store.exhaustivity = .off
    await store.send(.view(.photoTaken(jpeg)))
    await store.receive(\.described) { $0.step = .recognised }
    await store.send(.view(.thatsItTapped))
    await store.send(.view(.saveTapped))
    await store.receive(\.saved) {
      $0.awaiting = "watches"
      $0.step = .notShipped
    }
    await store.send(.view(.countMeInTapped)) { $0.step = .payoff }
    await store.finish()

    let snapshot = try shelfNow()
    let piece = try #require(snapshot.shelf.objects.values.first)
    #expect(piece.typeID == "thing")
    #expect(piece.awaitingType == "watches")
    #expect(snapshot.shelf.collections.values.map(\.name) == ["Collection"])
    #expect(snapshot.typeTesters.contains("watches"))
  }

  /// Nothing recognised: *What is it?*, which won't go on without a name, and a type the collector picks.
  @Test func nothingRecognisedAsksWhatItIs() async throws {
    let store = TestStore(initialState: FirstPieceFeature.State()) {
      FirstPieceFeature()
    } withDependencies: {
      $0.extraction.describePhoto = { _ in PieceDescription() }
    }
    await store.send(.view(.photoTaken(jpeg))) {
      $0.photo = jpeg
      $0.step = .reading
    }
    await store.receive(\.described) { $0.step = .whatIsIt }
    #expect(!store.state.canContinue)
    await store.send(.view(.nextTapped))
    await store.send(.view(.nameChanged("Kid A"))) { $0.name = "Kid A" }
    await store.send(.view(.typeTapped("music"))) { $0.type = "music" }
    await store.send(.view(.yearChanged("2000"))) { $0.year = 2000 }
    await store.send(.view(.nextTapped)) { $0.step = .story }
    await store.send(.view(.saveTapped)) { $0.isSaving = true }
    await store.receive(\.saved) {
      $0.isSaving = false
      $0.saved = try shelfNow().shelf.objects.keys.first
      $0.payoff = FirstPiecePayoff(line: nil)
      $0.step = .payoff
    }
    #expect(try shelfNow().shelf.collections.values.map(\.name) == ["My Music"])
    #expect(try shelfNow().shelf.objects.values.first?.values[.year] == .year(2000))
  }

  /// Without Apple Intelligence a photo's guess comes from Vision's labels alone; typing the name keeps it (review).
  @Test func aGuessFromThePhotoSurvivesTypingItsName() async throws {
    let store = TestStore(initialState: FirstPieceFeature.State()) {
      FirstPieceFeature()
    } withDependencies: {
      $0.extraction.describePhoto = { _ in PieceDescription(name: nil, words: ["wristwatch"]) }
    }
    store.exhaustivity = .off
    await store.send(.view(.photoTaken(jpeg)))
    await store.receive(\.described) { $0.step = .whatIsIt }
    #expect(store.state.type == "watches")
    await store.send(.view(.nameChanged("Omega")))
    #expect(store.state.type == "watches")
  }

  /// A typed name's year from the model isn't shown, so it isn't kept (review): only what the collector saw is theirs.
  @Test func aYearTheCollectorDidntSeeIsntKept() async throws {
    let store = TestStore(initialState: FirstPieceFeature.State()) {
      FirstPieceFeature()
    } withDependencies: {
      $0.extraction.isModelAvailable = { true }
      $0.extraction.describeText = { _ in PieceDescription(name: "Kid A", words: ["album"], year: 2000) }
    }
    store.exhaustivity = .off
    await store.send(.view(.typeItTapped))
    await store.send(.view(.nameChanged("Kid A")))
    await store.send(.view(.nextTapped))
    await store.receive(\.typedDescribed)
    #expect(store.state.year == nil)
  }

  /// A second tap while a save is under way, or after it, does nothing: one piece, one write.
  @Test func savingTwiceDoesNothing() async throws {
    var state = FirstPieceFeature.State()
    state.step = .story
    state.name = "Kid A"
    state.isSaving = true
    let store = TestStore(initialState: state) { FirstPieceFeature() }
    await store.send(.view(.saveTapped))
    #expect(try shelfNow().shelf.objects.isEmpty)
  }

  /// A model that fails is a piece nobody named yet, never an error.
  @Test func aModelThatFailsAsksWhatItIs() async throws {
    struct Failure: Error {}
    let store = TestStore(initialState: FirstPieceFeature.State()) {
      FirstPieceFeature()
    } withDependencies: {
      $0.extraction.describePhoto = { _ in throw Failure() }
    }
    await withKnownIssue {
      await store.send(.view(.photoTaken(jpeg))) {
        $0.photo = jpeg
        $0.step = .reading
      }
      await store.receive(\.describeFailed) { $0.step = .whatIsIt }
    }
  }

  /// Typed, with no type picked: the model says what kind of thing the name is, and the name stands.
  @Test func aTypedNameIsDescribedWhenNoTypeIsPicked() async throws {
    let store = TestStore(initialState: FirstPieceFeature.State()) {
      FirstPieceFeature()
    } withDependencies: {
      $0.extraction.isModelAvailable = { true }
      $0.extraction.describeText = { _ in PieceDescription(name: "Twilight Imperium", words: ["board game"]) }
    }
    await store.send(.view(.typeItTapped)) { $0.step = .whatIsIt }
    await store.send(.view(.nameChanged("Twilight Imperium"))) { $0.name = "Twilight Imperium" }
    await store.send(.view(.nextTapped)) { $0.step = .reading }
    await store.receive(\.typedDescribed) {
      $0.words = ["board game"]
      $0.guess = TypeGuess(type: "board-games", subtype: nil, isEnabled: true)
      $0.type = "board-games"
      $0.step = .story
    }
  }

  /// **Just look around first**: a setting, so the app stops opening on the first piece.
  @Test func lookingAroundFirstIsRemembered() async throws {
    let store = TestStore(initialState: FirstPieceFeature.State()) { FirstPieceFeature() }
    await store.send(.view(.lookAroundTapped))
    await store.receive(\.delegate.skipped)
    #expect(try shelfNow().firstPieceSkipped)
    #expect(try !shelfNow().opensOnFirstPiece)
  }
}

/// The events the shelf's log holds, oldest first.
enum ShelfEvents {
  @MainActor
  static func all() throws -> [ShelfEvent] {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.catalogue) var catalogue
    return try ShelfStore(migrated: database, catalogue: catalogue).log()
  }
}

/// A shelf that gained objects since onboarding opened (another device's, through sync): the piece is saved as an
/// ordinary typed add, with its story as the note, rather than refused for good (review).
@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct FirstPieceOnAShelfThatFilledUpTests {
  @Test func aRefusedFirstPieceIsSavedAsAnOrdinaryPiece() async throws {
    var state = FirstPieceFeature.State()
    state.step = .story
    state.name = "A first piece that came late"
    state.type = "board-games"
    state.chip = .gift
    let before = try shelfNow().shelf.objects.count
    let store = TestStore(initialState: state) { FirstPieceFeature() }
    store.exhaustivity = .off
    await store.send(.view(.saveTapped))
    await store.receive(\.saveRefused)
    await store.receive(\.saved) { $0.step = .payoff }
    let shelf = try shelfNow().shelf
    #expect(shelf.objects.count == before + 1)
    let piece = try #require(shelf.objects.values.first { $0.title == "A first piece that came late" })
    #expect(piece.values[.notes] == .text("A gift"))
    #expect(shelf.collections[piece.collectionID]?.typeID == "board-games")
  }
}

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

@testable import FindFeature

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct FindFeatureTests {
  func results(_ store: TestStoreOf<FindFeature>) -> [SearchHit] {
    @Dependency(\.catalogue) var catalogue
    return search(store.state.query, in: store.state.snapshot.shelf, catalogue: catalogue)
  }

  /// The status chip (D-59): only what's due shows under *watch*.
  @Test func theStatusChipFiltersByDerivedStatus() async throws {
    let due = try dueCartridge()
    let store = TestStore(initialState: FindFeature.State()) { FindFeature() }
    try await store.state.$snapshot.load()
    #expect(store.state.statusChoices.contains(.watch))
    await store.send(.view(.statusTapped(.watch))) { $0.query.status = .watch }
    // This one and the seed's Tetris.
    #expect(store.state.hits.count == 2)
    #expect(store.state.hits.map(\.object).contains(due))
    await store.send(.view(.statusTapped(.watch))) { $0.query.status = nil }
  }

  /// F11's done-when: chips stack, and each result names the field that matched.
  @Test func chipsStackAndEachResultSaysWhatMatched() async {
    let store = TestStore(initialState: FindFeature.State()) { FindFeature() }
    await store.send(.view(.textChanged("treasure"))) { $0.query.text = "treasure" }
    #expect(results(store).map(\.matched) == [["Publisher"]])
    await store.send(.view(.textChanged("Office"))) { $0.query.text = "Office" }
    #expect(results(store).count == 2)
    await store.send(.view(.typeTapped("music"))) { $0.query.types = ["music"] }
    #expect(results(store).isEmpty)
    await store.send(.view(.typeTapped("music"))) { $0.query.types = [] }
    await store.send(.view(.lentOutTapped)) { $0.query.lentOut = true }
    #expect(results(store).isEmpty)
    await store.send(.view(.clearTapped)) { $0.query = SearchQuery() }
  }

  @Test func theArchiveChipBringsBackWhatWasLetGo() async {
    let store = TestStore(initialState: FindFeature.State()) { FindFeature() }
    await store.send(.view(.textChanged("azul"))) { $0.query.text = "azul" }
    #expect(results(store).isEmpty)
    await store.send(.view(.archiveTapped)) { $0.query.includeArchive = true }
    #expect(results(store).count == 1)
  }

  @Test func aSavedViewIsALiveQuery() async {
    let store = TestStore(initialState: FindFeature.State()) { FindFeature() }
    await store.send(.view(.viewTapped(.imperfect))) { $0.query.view = .imperfect }
    // The seed's Saturn game has a manual graded Good, which isn't worn: nothing is imperfect yet.
    #expect(results(store).isEmpty)
  }

  @Test func aResultOpensItsObject() async {
    let store = TestStore(initialState: FindFeature.State()) { FindFeature() }
    await store.send(.view(.textChanged("kid a"))) { $0.query.text = "kid a" }
    let id = results(store)[0].object
    await store.send(.view(.resultTapped(id)))
    await store.receive(\.delegate.open, .object(id))
  }
}

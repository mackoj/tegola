#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaCatalogue
  import TegolaFixtures
  import TegolaInterchange
  import TegolaModel
  import TegolaSnapshotTesting
  import Testing

  @testable import ImportFeature

  /// Bring your list (T6.10), on Jeux.
  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf(seed: false) })
  struct ImportSnapshotTests {
    func jeux() async throws -> ImportFeature.State {
      let input = ImportInput(fileName: "Jeux collection.csv", data: try Fixture.jeuxCollection.data())
      let plan = try await SpreadsheetImporter().plan(input, catalogue: try Catalogue.bundled(), extraction: NoteReader())
      var state = ImportFeature.State()
      state.fileName = "Jeux collection.csv"
      state.plan = plan
      state.collectionName = plan.collectionName
      state.importers = ["spreadsheet"]
      return state
    }

    @Test func pick() {
      let store = Store(initialState: ImportFeature.State()) { ImportFeature() }
      assertScreenSnapshot(of: ImportView(store: store), named: "pick", suite: "import", height: 852)
    }

    @Test func sentence() async throws {
      var state = try await jeux()
      state.step = .sentence
      let store = Store(initialState: state) { ImportFeature() }
      assertScreenSnapshot(of: ImportView(store: store), named: "sentence", suite: "import", height: 1000)
    }

    @Test func payoff() async throws {
      var state = try await jeux()
      state.step = .payoff
      state.objects = (0..<485).map { ObjectID(UUID($0)) }
      state.matched = 412
      let store = Store(initialState: state) { ImportFeature() }
      assertScreenSnapshot(of: ImportView(store: store), named: "payoff", suite: "import", height: 1000)
    }
  }
#endif

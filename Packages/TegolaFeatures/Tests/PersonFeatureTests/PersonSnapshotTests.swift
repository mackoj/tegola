#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import SwiftUI
  import TegolaClients
  import TegolaModel
  import TegolaSnapshotTesting
  import Testing

  @testable import PersonFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct PersonSnapshotTests {
    /// Max has Kid A and once had Homogenic, back in the same shape.
    @Test func max() throws {
      @Dependency(\.shelf) var shelf
      let homogenic = try #require(try shelfNow().objects.values.first { $0.title == "Homogenic" }?.id)
      let max = try person("Max")
      _ = try shelf.perform(.lend(homogenic, to: .existing(max), due: nil, note: ""))
      let loan = try #require(try shelfNow().openLoan(on: homogenic))
      _ = try shelf.perform(.returnLoan(loan.id, cameBack: .sameShape, condition: nil))
      let store = Store(initialState: PersonFeature.State(id: max)) { PersonFeature() }
      assertScreenSnapshot(of: PersonView(store: store), named: "max", suite: "person", height: 1000)
    }

    /// Léa lent you Root: her page says so, with the dashed edge.
    @Test func lea() throws {
      let lea = try person("Léa")
      let store = Store(initialState: PersonFeature.State(id: lea)) { PersonFeature() }
      assertScreenSnapshot(of: PersonView(store: store), named: "lea", suite: "person", height: 800)
    }

    @Test func picker() throws {
      let max = try person("Max")
      let store = Store(initialState: PersonFeature.State(id: max)) { PersonFeature() }
      assertScreenSnapshot(of: PersonView(store: store).picker, named: "picker", suite: "person", height: 1200)
    }
  }
#endif

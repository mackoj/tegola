#if os(iOS)
  import ComposableArchitecture
  import DependenciesTestSupport
  import FeatureTestSupport
  import ShelfViews
  import SwiftUI
  import TegolaClients
  import TegolaModel
  import TegolaSnapshotTesting
  import Testing

  @testable import WishlistFeature

  @MainActor
  @Suite(.serialized, .dependencies { try $0.seededShelf() })
  struct WishlistSnapshotTests {
    @Test func wishlist() throws {
      let store = Store(initialState: WishlistFeature.State()) { WishlistFeature() }
      assertScreenSnapshot(of: WishlistView(store: store), named: "wishlist", suite: "wishlist", height: 900)
    }

    /// PD-071: the shared card shows wants, never holdings or prices.
    @Test func card() throws {
      @Dependency(\.catalogue) var catalogue
      let card = WishlistCard(shelf: try shelfNow())
      assertScreenSnapshot(
        of: WishlistCardView(card: card, catalogue: catalogue),
        named: "card",
        suite: "wishlist",
        width: 360
      )
    }
  }
#endif

#if os(iOS)
  import TegolaDesignSystem
  import TegolaSnapshotTesting
  import Testing

  /// Every catalog section (PLAN §2.6). Runs on the simulator only (`scripts/test.sh ios:TegolaDesignSystem`).
  @MainActor
  @Suite(.serialized) struct CatalogSnapshotTests {
    @Test(arguments: DesignSystemCatalog.Section.allCases)
    func section(_ section: DesignSystemCatalog.Section) {
      assertScreenSnapshot(of: DesignSystemCatalog.view(section), named: section.rawValue, suite: "catalog")
    }
  }
#endif

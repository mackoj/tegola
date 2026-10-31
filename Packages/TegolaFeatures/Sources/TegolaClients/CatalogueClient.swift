public import Dependencies
public import TegolaCatalogue

/// The bundled types, for the screens that draw a type's mark, tint and nouns. A value, not a client: it's pure and the
/// same everywhere (PLAN §5). Tests use the same bundle; a missing or invalid one is a failing catalogue test.
private enum CatalogueKey: DependencyKey {
  static let liveValue: Catalogue = {
    do {
      return try Catalogue.bundled()
    } catch {
      reportIssue(error)
      return Catalogue(manifests: [])
    }
  }()
}

extension DependencyValues {
  public var catalogue: Catalogue {
    get { self[CatalogueKey.self] }
    set { self[CatalogueKey.self] = newValue }
  }
}

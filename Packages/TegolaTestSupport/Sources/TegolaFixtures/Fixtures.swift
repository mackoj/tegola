public import Foundation

/// A fixture file, by name. Every fixture says where it came from in `Fixtures/README.md`.
public enum Fixture: String, CaseIterable, Sendable {
  /// A real collector's video-game spreadsheet (original-spec/uploads): 485 games in a grid of 20 platform columns,
  /// semicolons, CRLF, French notes in cells, typos and bundles. The import's test file (PLAN F9).
  case jeuxCollection = "Jeux collection.csv"

  public var url: URL {
    guard let url = Bundle.module.url(forResource: rawValue, withExtension: nil, subdirectory: "Fixtures") else {
      preconditionFailure("missing fixture \(rawValue)")
    }
    return url
  }

  public func data() throws -> Data { try Data(contentsOf: url) }
}

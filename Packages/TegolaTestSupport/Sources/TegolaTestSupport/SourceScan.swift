public import Foundation

/// The repository, found from this file's location, and its Swift sources: what the guard tests scan.
public enum Repository {
  public static let root: URL = URL(filePath: #filePath)
    .deletingLastPathComponent()  // TegolaTestSupport
    .deletingLastPathComponent()  // Sources
    .deletingLastPathComponent()  // TegolaTestSupport package
    .deletingLastPathComponent()  // Packages
    .deletingLastPathComponent()  // repo

  /// Every `.swift` file under `Packages/*/Sources` and the app target, skipping build products.
  public static func sourceFiles(packages: [String]? = nil, includeApp: Bool = true) throws -> [SourceFile] {
    let fileManager = FileManager.default
    let packagesURL = root.appending(path: "Packages")
    let names = try packages ?? fileManager.contentsOfDirectory(atPath: packagesURL.path()).sorted()
    var roots = names.map { packagesURL.appending(path: "\($0)/Sources") }
    if includeApp { roots.append(root.appending(path: "Tegola")) }
    var files: [SourceFile] = []
    for directory in roots where fileManager.fileExists(atPath: directory.path()) {
      guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else { continue }
      for case let url as URL in enumerator where url.pathExtension == "swift" && !url.path().contains("/.build/") {
        let relative = String(url.path().dropFirst(root.path().count))
        files.append(SourceFile(path: relative, text: try String(contentsOf: url, encoding: .utf8)))
      }
    }
    return files
  }
}

public struct SourceFile: Sendable, CustomStringConvertible {
  public let path: String
  public let text: String

  public var description: String { path }

  /// Lines matching `pattern`, as "path:line: text", ignoring `//` comment lines.
  public func matches(_ pattern: String) throws -> [String] {
    let regex = try Regex(pattern)
    return text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { index, line in
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard !trimmed.hasPrefix("//"), line.contains(regex) else { return nil }
      return "\(path):\(index + 1): \(trimmed)"
    }
  }
}

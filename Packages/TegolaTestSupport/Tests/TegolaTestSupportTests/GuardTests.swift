import Foundation
import TegolaFixtures
import TegolaTestSupport
import Testing

/// Rules that hold in every source file, checked by reading the sources (PLAN §2.5, §2.6, §4.0). They replace clctn's
/// git hook (PLAN §0 row 3): a test runs everywhere, a hook only where someone installed it.
@Suite struct GuardTests {
  struct Rule: CustomTestStringConvertible, Sendable {
    let name: String
    let pattern: String
    /// Files allowed to match, by path suffix.
    let allowed: [String]
    /// Lines that must match, so a broken pattern can't pass silently.
    let samples: [String]
    /// Only package sources (the app target uses its own bundle and may differ).
    var packagesOnly = false
    var testDescription: String { name }
  }

  static let systemColours =
    "red|green|blue|orange|yellow|pink|purple|cyan|mint|teal|indigo|brown|gray|grey|black|white"
    + "|primary|secondary|tertiary|quaternary|accentColor"

  static let rules: [Rule] = [
    Rule(
      name: "no world access outside dependencies",
      pattern:
        #"\b(Date\(\)|Date\.now|Date\(timeIntervalSinceNow|UUID\(\)|(Locale|Calendar|TimeZone)\.(current|autoupdatingCurrent)|URLSession\.shared)"#,
      allowed: [],
      samples: ["let now = Date()", "let now = Date.now", "Locale.autoupdatingCurrent", "TimeZone.current"]
    ),
    Rule(name: "no print", pattern: #"(^|[^.\w])print\("#, allowed: [], samples: [#"print("x")"#]),
    Rule(
      name: "no colour literal outside the palette",
      pattern:
        #"(#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?\b|0x[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?\b|(Color|UIColor|CGColor)\(\s*(\.sRGB|\.displayP3|\.linearSRGB|red:|hue:|white:|displayP3Red:))"#,
      allowed: ["TegolaDesignTokens/Palette.swift", "TegolaDesignSystem/Theme+SwiftUI.swift"],
      samples: [
        "let c = 0xFF5B2E", "let c = 0xFF5B2E80", "Color(.displayP3, red: 1, green: 0, blue: 0)", "Color(hue: 0.1)",
      ]
    ),
    Rule(
      name: "no system colour",
      pattern:
        #"(\b(Color|UIColor)\.(\#(systemColours)|system\w+)\b|(foregroundStyle|foregroundColor|fill|stroke|strokeBorder|background|tint|border|overlay|shadow)\(\s*\.(\#(systemColours))\b)"#,
      allowed: [],
      samples: [
        ".foregroundStyle(Color.red)", ".foregroundStyle(.red)", ".tint(.blue)", ".foregroundStyle(.secondary)",
      ]
    ),
    Rule(
      name: "no palette colour outside a theme (PLAN §4.0)",
      pattern: #"\bTegolaPalette\."#,
      allowed: ["TegolaDesignTokens/Palette.swift", "TegolaDesignTokens/Theme.swift"],
      samples: [".foregroundStyle(TegolaPalette.orange.color)"]
    ),
    Rule(
      name: "no font name or system font outside Fonts.swift",
      pattern:
        #"(\.custom\(|Font\.system\(|\.system\(size:|UIFont\(name:|UIFont\.systemFont|\.font\(\s*\.(largeTitle|title|title2|title3|headline|subheadline|body|callout|footnote|caption|caption2|system)\b)"#,
      allowed: ["TegolaDesignSystem/Fonts.swift"],
      samples: [#".font(.custom("Archivo", size: 13))"#, ".font(.body)", ".font(.system(size: 12))"]
    ),
    Rule(
      name: "no un-bundled UI string literal in a package (telaio REVIEW §7)",
      pattern: #"\b(Text|Button|Label|Toggle|TextField|Section|Picker|LocalizedStringKey)\(\s*"(?!.*bundle:)"#,
      allowed: [],
      samples: [#"Text("Shelf")"#, #"Button("Lend it") { }"#],
      packagesOnly: true
    ),
    Rule(
      name: "no public log interpolation",
      pattern: #"privacy:\s*\.public"#,
      allowed: [],
      samples: [#"logger.error("\(e, privacy: .public)")"#]
    ),
  ]

  @Test(arguments: rules)
  func holdsEverywhere(_ rule: Rule) throws {
    let files = try Repository.sourceFiles(includeApp: !rule.packagesOnly)
    #expect(!files.isEmpty)
    let hits =
      try files
      .filter { file in !rule.allowed.contains { file.path.hasSuffix($0) } }
      .flatMap { try $0.matches(rule.pattern) }
    #expect(hits.isEmpty, "\(rule.name):\n\(hits.joined(separator: "\n"))")
  }

  @Test(arguments: rules)
  func catchesItsSamples(_ rule: Rule) throws {
    let regex = try Regex.guardPattern(rule.pattern)
    for sample in rule.samples {
      #expect(sample.contains(regex), "\(rule.name) misses: \(sample)")
    }
  }

  static let anyImport =
    #"^\s*(@\w+\s+)*((public|package|internal|private|fileprivate)\s+)?(@\w+\s+)*import\s+((struct|class|enum|protocol|func|var|let|typealias)\s+)?"#

  /// The pure packages build on Linux, so they import no Apple UI or OS framework (PLAN §2.4, D-32).
  @Test func purePackagesImportNoAppleFramework() throws {
    let pure = ["TegolaCatalogue", "TegolaModel", "TegolaInterchange", "TegolaLookupAPI", "TegolaTestSupport"]
    let files = try Repository.sourceFiles(packages: pure, includeApp: false)
    #expect(!files.isEmpty)
    let frameworks =
      "SwiftUI|UIKit|AppKit|os|OSLog|CoreText|CoreGraphics|Combine|CryptoKit|VisionKit|CloudKit|DeviceCheck|SQLiteData|GRDB"
    let hits = try files.flatMap { try $0.matches(Self.anyImport + "(\(frameworks))\\b") }
    #expect(hits.isEmpty, "\(hits.joined(separator: "\n"))")
  }

  @Test func importRuleCatchesEverySpelling() throws {
    let regex = try Regex.guardPattern(Self.anyImport + "(SwiftUI|os)\\b")
    for line in [
      "import SwiftUI", "public import SwiftUI", "@preconcurrency public import SwiftUI", "private import os",
      "package import SwiftUI", "@_exported import SwiftUI", "import struct SwiftUI.Color",
    ] {
      #expect(line.contains(regex), "misses: \(line)")
    }
  }

  /// The design tokens are pure too: their contrast tests run on Linux.
  @Test func designTokensImportNoUIFramework() throws {
    let files = try Repository.sourceFiles(packages: ["TegolaDesignSystem"], includeApp: false)
      .filter { $0.path.contains("/TegolaDesignTokens/") }
    #expect(!files.isEmpty)
    let hits = try files.flatMap { try $0.matches(Self.anyImport + "(SwiftUI|UIKit|AppKit|CoreText|CoreGraphics)\\b") }
    #expect(hits.isEmpty, "\(hits.joined(separator: "\n"))")
  }
}

/// Every string a package localizes is in its target's String Catalog with a French entry, and every catalog key is
/// still used (telaio's StringCatalogCoverageTests; PLAN §2.5, PD-156).
@Suite struct StringCatalogCoverageTests {
  struct Catalog: Decodable {
    struct Entry: Decodable { let localizations: [String: AnyLocalization]? }
    struct AnyLocalization: Decodable {}
    let strings: [String: Entry]
  }

  /// A key's literal may interpolate (`"\\(count) objects"`): the catalog stores those as format specifiers.
  static let keyPatterns = [
    // swift-format may break a long call after the parenthesis: `String(\n  localized: "…"`.
    #"String\(\s*localized:\s*"((?:[^"\\]|\\\((?:[^()"]|\([^()"]*\))*\))+)""#,
    #"Text\(\s*"((?:[^"\\]|\\\((?:[^()"]|\([^()"]*\))*\))+)",\s*bundle:"#,
  ]

  /// One spelling for a source key and its catalog key: each interpolation (one level of nested calls allowed) and
  /// each format specifier becomes `%_`.
  static func normalized(_ key: String) -> String {
    key.replacing(/\\\((?:[^()"]|\([^()"]*\))*\)/, with: "%_").replacing(/%(\d+\$)?(lld|ld|d|@|f|lf)/, with: "%_")
  }

  @Test func everyKeyIsInItsCatalogWithFrenchAndNoneIsStale() throws {
    let catalogs = try Repository.stringCatalogs()
    #expect(!catalogs.isEmpty)
    for (target, url) in catalogs {
      let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
      let used = Set(try Self.keys(in: target).map(Self.normalized))
      let name = target.lastPathComponent
      let entries = Dictionary(catalog.strings.map { (Self.normalized($0.key), $0.value) }) { first, _ in first }
      for key in used.sorted() {
        let entry = entries[key]
        #expect(entry != nil, "\(name): \"\(key)\" is used but not in the catalog")
        #expect(entry?.localizations?["fr"] != nil, "\(name): \"\(key)\" has no French")
      }
      for key in Set(entries.keys).subtracting(used).sorted() {
        Issue.record("\(name): \"\(key)\" is in the catalog but no longer used")
      }
    }
  }

  /// A target that localizes with `bundle: .module` needs a catalog, or `Bundle.module` doesn't exist.
  @Test func everyTargetThatLocalizesHasACatalog() throws {
    let withCatalogs = Set(try Repository.stringCatalogs().map(\.target.lastPathComponent))
    let files = try Repository.sourceFiles(includeApp: false).filter { $0.text.contains("bundle: .module") }
    for file in files {
      let parts = file.path.split(separator: "/")
      guard let index = parts.firstIndex(of: "Sources"), index + 1 < parts.count else { continue }
      let target = String(parts[index + 1])
      // These targets have resources (fonts, type files, fixtures) but no user-facing strings.
      if ["TegolaDesignSystem", "TegolaCatalogue", "TegolaFixtures"].contains(target) { continue }
      #expect(withCatalogs.contains(target), "\(file.path) localizes but \(target) has no Localizable.xcstrings")
    }
  }

  static func keys(in target: URL) throws -> Set<String> {
    var keys: Set<String> = []
    let enumerator = FileManager.default.enumerator(at: target, includingPropertiesForKeys: nil)
    while let url = enumerator?.nextObject() as? URL {
      guard url.pathExtension == "swift" else { continue }
      let text = try String(contentsOf: url, encoding: .utf8)
      for pattern in keyPatterns {
        for match in text.matches(of: try Regex(pattern)) {
          if let key = match.output[1].substring { keys.insert(String(key)) }
        }
      }
    }
    return keys
  }
}

@Suite struct FixtureTests {
  @Test func jeuxCollectionIsTheRealFile() throws {
    let text = try #require(String(data: try Fixture.jeuxCollection.data(), encoding: .utf8))
    #expect(text.hasPrefix(";Ps1;Ps2;"))
  }
}

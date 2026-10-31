import Foundation
import TegolaFixtures
import TegolaTestSupport
import Testing

/// Rules that hold in every source file, checked by reading the sources (PLAN §2.5, §2.6). They replace clctn's git
/// hook (PLAN §0 row 3): a test runs everywhere, a hook only where someone installed it.
@Suite struct GuardTests {
  struct Rule: CustomTestStringConvertible, Sendable {
    let name: String
    let pattern: String
    /// Files allowed to match, by path suffix.
    let allowed: [String]
    /// Text that must match, so a broken pattern can't pass silently.
    let sample: String
    var testDescription: String { name }
  }

  static let rules: [Rule] = [
    Rule(
      name: "no world access outside dependencies",
      pattern: #"\b(Date\(\)|UUID\(\)|Locale\.current|Calendar\.current|URLSession\.shared)"#,
      allowed: [],
      sample: "let now = Date()"
    ),
    Rule(name: "no print", pattern: #"(^|[^.\w])print\("#, allowed: [], sample: #"print("x")"#),
    Rule(
      name: "no colour literal outside the tokens",
      pattern: #"(#[0-9A-Fa-f]{6}\b|0x[0-9A-Fa-f]{6}\b|Color\(red:|Color\(\.sRGB|UIColor\(red:)"#,
      allowed: ["TegolaDesignTokens/Palette.swift", "TegolaDesignSystem/Theme+SwiftUI.swift"],
      sample: "let c = 0xFF5B2E"
    ),
    Rule(
      name: "no system colour",
      pattern:
        #"\b(Color|UIColor)\.(red|green|blue|orange|yellow|pink|purple|gray|black|white|primary|secondary|system\w+)\b"#,
      allowed: [],
      sample: ".foregroundStyle(Color.red)"
    ),
    Rule(
      name: "no public log interpolation",
      pattern: #"privacy:\s*\.public"#,
      allowed: [],
      sample: #"logger.error("\(e, privacy: .public)")"#
    ),
  ]

  @Test(arguments: rules)
  func holdsEverywhere(_ rule: Rule) throws {
    let files = try Repository.sourceFiles()
    #expect(!files.isEmpty)
    let hits =
      try files
      .filter { file in !rule.allowed.contains { file.path.hasSuffix($0) } }
      .flatMap { try $0.matches(rule.pattern) }
    #expect(hits.isEmpty, "\(rule.name):\n\(hits.joined(separator: "\n"))")
  }

  @Test(arguments: rules)
  func catchesItsSample(_ rule: Rule) throws {
    #expect(rule.sample.contains(try Regex(rule.pattern)))
  }

  /// The pure packages build on Linux, so they import no Apple UI or OS framework (PLAN §2.4).
  @Test func purePackagesImportNoAppleFramework() throws {
    let pure = ["TegolaCatalogue", "TegolaModel", "TegolaInterchange", "TegolaLookupAPI"]
    let files = try Repository.sourceFiles(packages: pure, includeApp: false)
    let hits = try files.flatMap {
      try $0.matches(
        #"^\s*(public |internal |@preconcurrency )?import (SwiftUI|UIKit|AppKit|os|CoreText|VisionKit|CloudKit|SQLiteData|GRDB)\b"#
      )
    }
    #expect(hits.isEmpty, "\(hits.joined(separator: "\n"))")
  }

  /// The design tokens are pure too: their contrast tests run on Linux.
  @Test func designTokensImportNoUIFramework() throws {
    let files = try Repository.sourceFiles(packages: ["TegolaDesignSystem"], includeApp: false)
      .filter { $0.path.contains("/TegolaDesignTokens/") }
    #expect(!files.isEmpty)
    let hits = try files.flatMap { try $0.matches(#"^\s*(public )?import (SwiftUI|UIKit|AppKit|CoreText)\b"#) }
    #expect(hits.isEmpty, "\(hits.joined(separator: "\n"))")
  }
}

@Suite struct FixtureTests {
  @Test func jeuxCollectionIsTheRealFile() throws {
    let text = try #require(String(data: try Fixture.jeuxCollection.data(), encoding: .utf8))
    #expect(text.hasPrefix(";Ps1;Ps2;"))
  }
}

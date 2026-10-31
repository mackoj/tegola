import Testing

@testable import TegolaDesignTokens

/// Every text/background pair a theme promises reads at WCAG AA (PLAN §2.6, telaio's ContrastTests).
@Suite struct ContrastTests {
  struct Case: CustomTestStringConvertible, Sendable {
    let theme: TegolaTheme
    let pair: TegolaContrastPair
    var testDescription: String { "\(theme.id): \(pair)" }
  }

  static let cases: [Case] = TegolaTheme.all.flatMap { theme in
    TegolaContrastPair.promised.map { Case(theme: theme, pair: $0) }
  }

  @Test(arguments: cases)
  func meetsAA(_ c: Case) {
    let ratio = c.theme[c.pair.text].contrast(with: c.theme[c.pair.background])
    #expect(ratio >= 4.5, "\(c.testDescription): \(ratio)")
  }

  @Test func ratioFunctionMatchesKnownValues() {
    let black = TegolaRGB(0x000000)
    let white = TegolaRGB(0xFFFFFF)
    #expect(abs(black.contrast(with: white) - 21) < 0.001)
    #expect(abs(TegolaRGB(0x777777).contrast(with: white) - 4.48) < 0.01)
    #expect(abs(TegolaPalette.ink.contrast(with: TegolaPalette.paper) - 15.74) < 0.01)
  }

  /// The derived tokens exist because the archive's own values fail; if they stop failing, the derivation can go.
  @Test func derivedTokensAreNecessary() {
    #expect(TegolaPalette.meta.contrast(with: TegolaPalette.paper) < 4.5)
    #expect(TegolaPalette.paper.contrast(with: TegolaPalette.orange) < 4.5)
    #expect(TegolaPalette.paper.contrast(with: TegolaPalette.pink) < 4.5)
  }
}

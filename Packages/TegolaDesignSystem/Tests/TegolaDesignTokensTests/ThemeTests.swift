import Testing

@testable import TegolaDesignTokens

@Suite struct ThemeTests {
  @Test(arguments: TegolaTheme.all)
  func everyThemeMapsEveryRole(_ theme: TegolaTheme) {
    for role in TegolaRole.allCases {
      #expect(theme.maps(role), "\(theme.id) has no colour for \(role)")
    }
  }

  @Test func themeIDsAreUnique() {
    #expect(Set(TegolaTheme.all.map(\.id)).count == TegolaTheme.all.count)
  }

  /// D27: not yours is a dashed edge in the rule colour, never a new colour.
  @Test func notYoursUsesTheDashedRuleColour() {
    #expect(TegolaTheme.board[.edgeNotYours] == TegolaPalette.ruleDark)
  }

  @Test func boardThemeMatchesTheArchiveWhereItPasses() {
    let board = TegolaTheme.board
    #expect(board[.surface] == TegolaPalette.paper)
    #expect(board[.text] == TegolaPalette.ink)
    #expect(board[.textMuted] == TegolaPalette.muted)
    #expect(board[.accentAction] == TegolaPalette.orange)
    #expect(board[.statusGood] == TegolaPalette.mint)
  }
}

@Suite struct MetricsTests {
  @Test func spacingScaleIsIncreasing() {
    #expect(TegolaSpace.scale == TegolaSpace.scale.sorted())
  }

  @Test(arguments: TegolaType.all.map(\.name))
  func textStylesRespectTheMinimumSizes(_ name: String) throws {
    let style = try #require(TegolaType.all.first { $0.name == name }?.style)
    let minimum = style.family == .mono ? TegolaType.minimumMonoSize : TegolaType.minimumTextSize
    #expect(style.size >= minimum)
  }

  @Test func displayStylesHoldTheirOpticalSize() {
    for (_, style) in TegolaType.all where style.family == .display {
      #expect(style.scalesWithDynamicType == false)
    }
  }

  @Test func hitTargetIsAtLeast44() {
    #expect(TegolaMetrics.minimumHitTarget >= 44)
  }
}

@Suite struct FontFaceTests {
  /// The faces come from the files' name tables (review of M1, item 7).
  @Test func variableFacesOpenTheirDefaultInstanceAndSetWeight() {
    #expect(TegolaFontFamily.text.face(weight: 700, size: 14).postScriptName == "Archivo-SemiBold")
    #expect(TegolaFontFamily.text.face(weight: 700, size: 14).axes == [.weight: 700])
    let display = TegolaFontFamily.display.face(weight: 800, size: 34)
    #expect(display.postScriptName == "BricolageGrotesque-96ptExtraBold")
    #expect(display.axes == [.weight: 800, .opticalSize: 34])
  }

  @Test func opticalSizeStaysInsideTheFontsRange() {
    #expect(TegolaFontFamily.display.face(weight: 800, size: 140).axes[.opticalSize] == 96)
    #expect(TegolaFontFamily.display.face(weight: 800, size: 8).axes[.opticalSize] == 12)
  }

  @Test func monoPicksTheFileForTheWeight() {
    #expect(TegolaFontFamily.mono.face(weight: 400, size: 10).postScriptName == "DMMono-Regular")
    #expect(TegolaFontFamily.mono.face(weight: 500, size: 10).postScriptName == "DMMono-Medium")
  }

  /// Only Regular and Medium of DM Mono are bundled, so no mono style may ask for more (PLAN §4.0: mono is 500).
  @Test func monoStylesUseABundledWeight() {
    for (name, style) in TegolaType.all where style.family == .mono {
      #expect([400, 500].contains(style.weight), "\(name)")
    }
  }
}

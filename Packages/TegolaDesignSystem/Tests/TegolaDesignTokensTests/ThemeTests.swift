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

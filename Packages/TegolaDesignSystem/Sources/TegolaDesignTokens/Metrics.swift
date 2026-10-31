/// The three families the boards use, and nothing else (PLAN §4.0). Never SF Pro as a substitute.
public enum TegolaFontFamily: String, CaseIterable, Sendable {
  /// Bricolage Grotesque (variable): titles, big numbers, type marks.
  case display
  /// Archivo (variable): UI and body.
  case text
  /// DM Mono: eyebrows, counts, spine labels, prices in tables.
  case mono

  /// The PostScript family name registered from `Resources/Fonts`.
  public var familyName: String {
    switch self {
    case .display: "Bricolage Grotesque"
    case .text: "Archivo"
    case .mono: "DM Mono"
    }
  }

  /// The font files that provide this family, relative to `Resources/Fonts`.
  public var files: [String] {
    switch self {
    case .display: ["BricolageGrotesque-Variable.ttf"]
    case .text: ["Archivo-Variable.ttf"]
    case .mono: ["DMMono-Regular.ttf", "DMMono-Medium.ttf"]
    }
  }
}

/// One text style from the boards, in points at the default Dynamic Type size. Tracking is in em, as the boards
/// write it; `lineHeight` is a multiple of the size.
public struct TegolaTextStyle: Hashable, Sendable {
  public let family: TegolaFontFamily
  public let size: Double
  public let weight: Int
  public let tracking: Double
  public let lineHeight: Double
  public let uppercased: Bool
  /// Display faces hold their designed optical size instead of scaling with Dynamic Type (handoff README).
  public let scalesWithDynamicType: Bool

  public init(
    _ family: TegolaFontFamily,
    size: Double,
    weight: Int,
    tracking: Double = 0,
    lineHeight: Double = 1.2,
    uppercased: Bool = false,
    scalesWithDynamicType: Bool = true
  ) {
    self.family = family
    self.size = size
    self.weight = weight
    self.tracking = tracking
    self.lineHeight = lineHeight
    self.uppercased = uppercased
    self.scalesWithDynamicType = scalesWithDynamicType
  }

  /// Tracking in points.
  public var trackingPoints: Double { tracking * size }
}

/// The type scale, from `docs/design/BOARDS.md` § Typography. The boards' CSS pixels map 1:1 to points.
public enum TegolaType {
  public static let displayTitle = TegolaTextStyle(
    .display,
    size: 34,
    weight: 800,
    tracking: -0.03,
    lineHeight: 0.96,
    scalesWithDynamicType: false
  )
  public static let displaySmall = TegolaTextStyle(
    .display,
    size: 24,
    weight: 800,
    tracking: -0.03,
    lineHeight: 1,
    scalesWithDynamicType: false
  )
  public static let bigNumber = TegolaTextStyle(
    .display,
    size: 26,
    weight: 800,
    tracking: -0.02,
    lineHeight: 1.1,
    scalesWithDynamicType: false
  )
  public static let typeMark = TegolaTextStyle(
    .display,
    size: 34,
    weight: 800,
    tracking: -0.04,
    lineHeight: 0.85,
    scalesWithDynamicType: false
  )
  public static let heading = TegolaTextStyle(.text, size: 15, weight: 700)
  public static let button = TegolaTextStyle(.text, size: 14, weight: 700)
  public static let label = TegolaTextStyle(.text, size: 13, weight: 600)
  public static let body = TegolaTextStyle(.text, size: 13, weight: 400, lineHeight: 1.5)
  public static let bodySmall = TegolaTextStyle(.text, size: 11, weight: 400, lineHeight: 1.4)
  public static let meta = TegolaTextStyle(.mono, size: 10, weight: 500, tracking: 0.14, uppercased: true)
  public static let metaSmall = TegolaTextStyle(.mono, size: 9, weight: 500, tracking: 0.12, uppercased: true)
  public static let numeric = TegolaTextStyle(.mono, size: 15, weight: 600)

  public static let all: [(name: String, style: TegolaTextStyle)] = [
    ("displayTitle", displayTitle), ("displaySmall", displaySmall), ("bigNumber", bigNumber), ("typeMark", typeMark),
    ("heading", heading), ("button", button), ("label", label), ("body", body), ("bodySmall", bodySmall),
    ("meta", meta), ("metaSmall", metaSmall), ("numeric", numeric),
  ]

  /// The boards never set text below this (BOARDS.md: "never below 11" for body; mono eyebrows go to 9).
  public static let minimumMonoSize: Double = 9
  public static let minimumTextSize: Double = 11
}

/// Spacing, from the design-system page: every padding and stack spacing comes from here.
public enum TegolaSpace {
  public static let xxs: Double = 4
  public static let xs: Double = 6
  public static let s: Double = 9
  public static let m: Double = 13
  public static let l: Double = 18
  public static let xl: Double = 22
  public static let xxl: Double = 34
  public static let gutter: Double = 20
  public static let gutterDense: Double = 18
  public static let gutterEmpty: Double = 24
  public static let topInset: Double = 66
  public static let bottomInsetWithTabBar: Double = 108

  public static let scale: [Double] = [xxs, xs, s, m, l, xl, xxl]
}

public enum TegolaRadius {
  public static let glyph: Double = 4
  public static let badge: Double = 6
  public static let chip: Double = 8
  public static let input: Double = 11
  public static let card: Double = 14
  public static let cardLarge: Double = 18
  public static let sheet: Double = 24
  /// Pills, buttons, avatars, toggles: fully round.
  public static let pill: Double = 999
}

public enum TegolaBorder {
  /// The default everywhere.
  public static let standard: Double = 2.5
  /// Small chips and segmented buttons.
  public static let chip: Double = 2
  public static let hairline: Double = 1.5
  /// The dash of the "not yours" and "add" edge.
  public static let dash: [Double] = [6, 6]
}

/// Hard offset shadows only: never blurred (handoff README).
public enum TegolaShadow {
  public static let small: Double = 3
  public static let large: Double = 4
  public static let document: Double = 5
}

public enum TegolaMetrics {
  public static let minimumHitTarget: Double = 44
  public static let tabBarHeight: Double = 88
  public static let scanButtonDiameter: Double = 40
  public static let scanButtonRaise: Double = 9
  public static let sheetGrabber: (width: Double, height: Double) = (46, 5)
  public static let halftoneSpacing: Double = 7
  public static let halftoneDot: Double = 1
}

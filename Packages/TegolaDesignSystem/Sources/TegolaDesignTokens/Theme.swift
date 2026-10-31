/// What a colour is *for*. Views name roles, never palette colours, so a new theme (dark, an event) is a new
/// `TegolaTheme` value and no view changes (PLAN §4.0, D-26).
public enum TegolaRole: String, CaseIterable, Hashable, Sendable {
  // Surfaces
  case surface  // screen background
  case surfaceSunken  // tracks, wells, inactive fills, footers
  case surfaceHeader  // sticky headers on warm screens
  case surfaceRaised  // cards
  case surfaceStage  // the dark object stage and dark cards
  case surfaceCamera  // camera and capture screens

  // Text
  case text  // primary text on light surfaces
  case textMuted  // secondary body text
  case textMeta  // mono eyebrows, counts, spine labels
  case textOnStage  // text on the stage and the camera

  // Lines and shadows
  case edge  // every solid border
  case edgeNotYours  // the dashed edge of wanted, borrowed and shared objects, and of "add" slots (D27)
  case hairline  // inert tracks, grabbers, timeline rails
  case shadow  // hard offset shadows on light surfaces
  case shadowOnStage  // hard offset shadows on dark surfaces

  // Accents, each with the text colour that reads on it
  case accentAction  // the primary call to action
  case onAccentAction
  case accentHighlight  // stickers, badges, the scan button, active camera segment
  case onAccentHighlight
  case accentGrail
  case onAccentGrail
  case accentConfirm  // confirm, ON toggles, positive
  case onAccentConfirm
  case accentInfo  // data, info banners
  case onAccentInfo
  case accentLoss  // overdue, loss: the only red
  case onAccentLoss

  // The five status swatches (PD-016), each with its text colour
  case statusFine
  case onStatusFine
  case statusGood
  case onStatusGood
  case statusWatch
  case onStatusWatch
  case statusAct
  case onStatusAct
  case statusGone
  case onStatusGone
}

/// A text role on a surface role that a theme promises will read (WCAG AA, 4.5:1). `ContrastTests` checks every pair
/// in every theme. Add a pair here when a component puts that text on that surface.
public struct TegolaContrastPair: Hashable, Sendable, CustomStringConvertible {
  public let text: TegolaRole
  public let background: TegolaRole

  public init(_ text: TegolaRole, on background: TegolaRole) {
    self.text = text
    self.background = background
  }

  public var description: String { "\(text) on \(background)" }

  public static let promised: [TegolaContrastPair] = {
    let light: [TegolaRole] = [.surface, .surfaceSunken, .surfaceRaised]
    var pairs: [TegolaContrastPair] = []
    for background in light {
      pairs += [.init(.text, on: background), .init(.textMuted, on: background), .init(.textMeta, on: background)]
    }
    pairs += [
      .init(.text, on: .surfaceHeader), .init(.textMeta, on: .surfaceHeader),
      .init(.textOnStage, on: .surfaceStage), .init(.textOnStage, on: .surfaceCamera),
      .init(.onAccentAction, on: .accentAction),
      .init(.onAccentHighlight, on: .accentHighlight), .init(.textMeta, on: .accentHighlight),
      .init(.onAccentGrail, on: .accentGrail),
      .init(.onAccentConfirm, on: .accentConfirm),
      .init(.onAccentInfo, on: .accentInfo),
      .init(.onAccentLoss, on: .accentLoss),
      .init(.onStatusFine, on: .statusFine),
      .init(.onStatusGood, on: .statusGood), .init(.textMeta, on: .statusGood),
      .init(.onStatusWatch, on: .statusWatch),
      .init(.onStatusAct, on: .statusAct),
      .init(.onStatusGone, on: .statusGone),
    ]
    return pairs
  }()
}

/// A complete mapping from roles to colours, plus the few non-colour values a theme may change.
public struct TegolaTheme: Hashable, Sendable, Identifiable {
  public let id: String
  private let colours: [TegolaRole: TegolaRGB]
  /// The halftone dot colour drawn over colour fields and cover art.
  public let halftone: TegolaRGB
  /// Opacity of the halftone dots on object tiles.
  public let halftoneOpacity: Double
  /// Opacity of the ink backdrop behind a bottom sheet.
  public let sheetBackdropOpacity: Double

  /// - Precondition: `colours` maps every `TegolaRole`; `ThemeTests.everyThemeMapsEveryRole` checks the shipped ones.
  public init(
    id: String,
    colours: [TegolaRole: TegolaRGB],
    halftone: TegolaRGB,
    halftoneOpacity: Double,
    sheetBackdropOpacity: Double
  ) {
    self.id = id
    self.colours = colours
    self.halftone = halftone
    self.halftoneOpacity = halftoneOpacity
    self.sheetBackdropOpacity = sheetBackdropOpacity
  }

  public subscript(role: TegolaRole) -> TegolaRGB {
    guard let colour = colours[role] else {
      preconditionFailure("theme \(id) has no colour for \(role)")
    }
    return colour
  }

  public func maps(_ role: TegolaRole) -> Bool { colours[role] != nil }

  public static let all: [TegolaTheme] = [.board]
}

extension TegolaTheme {
  /// The boards, exactly (PLAN §10 answer 5), with the derived text colours of answer 8: `textMeta` is #645A4E, and
  /// text on orange and pink is ink rather than paper.
  public static let board = TegolaTheme(
    id: "board",
    colours: [
      .surface: TegolaPalette.paper,
      .surfaceSunken: TegolaPalette.sand,
      .surfaceHeader: TegolaPalette.paperDeep,
      .surfaceRaised: TegolaPalette.card,
      .surfaceStage: TegolaPalette.ink,
      .surfaceCamera: TegolaPalette.camera,
      .text: TegolaPalette.ink,
      .textMuted: TegolaPalette.muted,
      .textMeta: TegolaPalette.metaText,
      .textOnStage: TegolaPalette.paper,
      .edge: TegolaPalette.ink,
      .edgeNotYours: TegolaPalette.ruleDark,
      .hairline: TegolaPalette.rule,
      .shadow: TegolaPalette.ink,
      .shadowOnStage: TegolaPalette.orange,
      .accentAction: TegolaPalette.orange,
      .onAccentAction: TegolaPalette.ink,
      .accentHighlight: TegolaPalette.yellow,
      .onAccentHighlight: TegolaPalette.ink,
      .accentGrail: TegolaPalette.pink,
      .onAccentGrail: TegolaPalette.ink,
      .accentConfirm: TegolaPalette.green,
      .onAccentConfirm: TegolaPalette.paper,
      .accentInfo: TegolaPalette.cobalt,
      .onAccentInfo: TegolaPalette.paper,
      .accentLoss: TegolaPalette.rust,
      .onAccentLoss: TegolaPalette.paper,
      .statusFine: TegolaPalette.sand,
      .onStatusFine: TegolaPalette.ink,
      .statusGood: TegolaPalette.mint,
      .onStatusGood: TegolaPalette.ink,
      .statusWatch: TegolaPalette.yellow,
      .onStatusWatch: TegolaPalette.ink,
      .statusAct: TegolaPalette.rust,
      .onStatusAct: TegolaPalette.paper,
      .statusGone: TegolaPalette.ink,
      .onStatusGone: TegolaPalette.paper,
    ],
    halftone: TegolaPalette.ink,
    halftoneOpacity: 0.22,
    sheetBackdropOpacity: 0.28
  )
}

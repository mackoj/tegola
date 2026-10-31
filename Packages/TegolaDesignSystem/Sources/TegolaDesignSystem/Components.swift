#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaDesignTokens

  // The shared components (BOARDS.md § Component inventory). They take `Text` for every word, so the caller's bundle
  // localizes it, and read colours only through theme roles.

  // MARK: - Titles

  /// A display title, broken across lines on purpose ("My / Collections"). Each line is its own `Text`, so the 0.96
  /// line height holds: SwiftUI can't set line spacing below a font's natural leading (D-26's follow-up).
  public struct DisplayTitle: View {
    let lines: [Text]
    let style: TegolaTextStyle

    public init(_ lines: [Text], style: TegolaTextStyle = TegolaType.displayTitle) {
      self.lines = lines
      self.style = style
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(lines.indices, id: \.self) { index in
          // Each line takes exactly size × line height; the glyphs may overhang it, as they do on the boards.
          lines[index]
            .tegolaTextStyle(style)
            .foregroundStyle(TegolaRole.text)
            .fixedSize()
            .frame(height: style.size * style.lineHeight, alignment: .center)
        }
      }
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(.isHeader)
    }
  }

  /// The top of a light screen: a mono eyebrow, a display title, and optionally a mono meta line and body text
  /// (board 01, chrome state 1: big title, no chevron, nothing behind it).
  public struct ScreenHeader<Accessory: View>: View {
    let eyebrow: Text?
    let title: [Text]
    let body_: Text?
    let accessory: Accessory

    public init(eyebrow: Text? = nil, title: [Text], body: Text? = nil, @ViewBuilder accessory: () -> Accessory) {
      self.eyebrow = eyebrow
      self.title = title
      self.body_ = body
      self.accessory = accessory()
    }

    public var body: some View {
      HStack(alignment: .bottom, spacing: TegolaSpace.m) {
        VStack(alignment: .leading, spacing: TegolaSpace.s) {
          if let eyebrow { eyebrow.tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta) }
          DisplayTitle(title)
          if let body_ {
            body_.tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 0)
        accessory
      }
    }
  }

  extension ScreenHeader where Accessory == EmptyView {
    public init(eyebrow: Text? = nil, title: [Text], body: Text? = nil) {
      self.init(eyebrow: eyebrow, title: title, body: body) { EmptyView() }
    }
  }

  // MARK: - Buttons

  /// The four button looks (board 33): Primary is ink with an orange shadow, Accent is orange with an ink shadow,
  /// Confirm is green, Secondary is an outline, Quiet is text only. All pills, at least 44 pt tall.
  public struct TegolaButtonStyle: ButtonStyle {
    public enum Kind: CaseIterable, Sendable {
      case primary, accent, confirm, secondary, quiet
    }

    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled

    public init(_ kind: Kind) {
      self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
      let label = configuration.label
        .tegolaTextStyle(TegolaType.button)
        .frame(maxWidth: kind == .quiet ? nil : .infinity, minHeight: TegolaMetrics.minimumHitTarget)
        .padding(.horizontal, TegolaSpace.l)
        .contentShape(Capsule())
      let pressed = configuration.isPressed ? TegolaShadow.small : 0
      return Group {
        switch kind {
        case .primary:
          label.foregroundStyle(TegolaRole.textOnStage)
            .printed(
              fill: .surfaceStage,
              radius: TegolaRadius.pill,
              shadow: TegolaShadow.small - pressed,
              shadowRole: .accentAction
            )
        case .accent:
          label.foregroundStyle(TegolaRole.onAccentAction)
            .printed(fill: .accentAction, radius: TegolaRadius.pill, shadow: TegolaShadow.small - pressed)
        case .confirm:
          label.foregroundStyle(TegolaRole.onAccentConfirm)
            .printed(fill: .accentConfirm, radius: TegolaRadius.pill, shadow: TegolaShadow.small - pressed)
        case .secondary:
          label.foregroundStyle(TegolaRole.text)
            .printed(fill: .surface, radius: TegolaRadius.pill, shadow: 0)
        case .quiet:
          label.foregroundStyle(TegolaRole.textMuted)
        }
      }
      .offset(x: pressed, y: pressed)
      .opacity(isEnabled ? 1 : 0.45)
    }
  }

  extension ButtonStyle where Self == TegolaButtonStyle {
    public static func tegola(_ kind: TegolaButtonStyle.Kind) -> TegolaButtonStyle { TegolaButtonStyle(kind) }
  }

  /// Two buttons side by side, sharing the width (board 33's ButtonPair).
  public struct ButtonPair<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

    public init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
      self.leading = leading()
      self.trailing = trailing()
    }

    public var body: some View {
      HStack(spacing: 10) {
        leading
        trailing
      }
    }
  }

  /// A dashed slot that invites: "+ Add a detail", "+ Photo". Same dash as not-yours, never an error (board 33).
  public struct DashedButton: View {
    let label: Text
    let action: () -> Void

    public init(_ label: Text, action: @escaping () -> Void) {
      self.label = label
      self.action = action
    }

    public var body: some View {
      Button(action: action) {
        label
          .tegolaTextStyle(TegolaType.label)
          .foregroundStyle(TegolaRole.textMeta)
          .frame(maxWidth: .infinity, minHeight: TegolaMetrics.minimumHitTarget)
          .contentShape(Rectangle())
          .notYours(radius: TegolaRadius.input)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Pills and chips

  /// A filter or sort pill (board 01): active is ink with paper text, inactive an outline.
  public struct Pill: View {
    let label: Text
    let isActive: Bool
    let action: () -> Void

    public init(_ label: Text, isActive: Bool, action: @escaping () -> Void) {
      self.label = label
      self.isActive = isActive
      self.action = action
    }

    public var body: some View {
      Button(action: action) {
        label
          .tegolaTextStyle(TegolaType.label)
          .foregroundStyle(isActive ? TegolaRole.textOnStage : TegolaRole.text)
          .padding(.horizontal, TegolaSpace.m)
          .frame(minHeight: TegolaMetrics.minimumHitTarget - 8)
          .printed(fill: isActive ? .surfaceStage : .surface, radius: TegolaRadius.pill, shadow: 0)
          .frame(minHeight: TegolaMetrics.minimumHitTarget)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(isActive ? .isSelected : [])
    }
  }

  /// A flat mono chip: a genre, a count, GRAIL. Tilt only on stickers that sit on an object, two per screen at most.
  public struct Chip: View {
    let label: Text
    let fill: TegolaRole
    let ink: TegolaRole
    let tilt: Double

    public init(_ label: Text, fill: TegolaRole = .surfaceRaised, ink: TegolaRole = .text, tilt: Double = 0) {
      self.label = label
      self.fill = fill
      self.ink = ink
      self.tilt = tilt
    }

    public var body: some View {
      label
        .tegolaTextStyle(TegolaType.metaSmall)
        .foregroundStyle(ink)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .printed(fill: fill, radius: TegolaRadius.pill, edge: TegolaBorder.chip, shadow: 0)
        .rotationEffect(.degrees(tilt))
    }
  }

  /// The five status swatches every object's chip comes from (PD-016). The model's `ObjectStatus` maps onto these.
  public enum StatusSwatch: String, CaseIterable, Sendable {
    case fine, good, watch, act, gone

    var fill: TegolaRole {
      switch self {
      case .fine: .statusFine
      case .good: .statusGood
      case .watch: .statusWatch
      case .act: .statusAct
      case .gone: .statusGone
      }
    }

    var ink: TegolaRole {
      switch self {
      case .fine: .onStatusFine
      case .good: .onStatusGood
      case .watch: .onStatusWatch
      case .act: .onStatusAct
      case .gone: .onStatusGone
      }
    }
  }

  /// One status chip: the swatch and its word.
  public struct StatusChip: View {
    let swatch: StatusSwatch
    let label: Text

    public init(_ swatch: StatusSwatch, label: Text) {
      self.swatch = swatch
      self.label = label
    }

    public var body: some View {
      Chip(label, fill: swatch.fill, ink: swatch.ink)
    }
  }

  // MARK: - Empty state

  /// An empty screen: a dashed frame, a heading, a line of body text and one action (board 02). Empty is always an
  /// invitation, never an error.
  public struct EmptyState<Action: View>: View {
    let title: [Text]
    let message: Text
    let action: Action

    public init(title: [Text], message: Text, @ViewBuilder action: () -> Action) {
      self.title = title
      self.message = message
      self.action = action()
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        DisplayTitle(title, style: TegolaType.displaySmall)
        message.tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
          .fixedSize(horizontal: false, vertical: true)
        action
      }
      .padding(TegolaSpace.xl)
      .frame(maxWidth: .infinity, alignment: .leading)
      .notYours(radius: TegolaRadius.emptyFrame)
    }
  }
#endif

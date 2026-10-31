#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaDesignTokens

  extension View {
    /// The printed-object look: an ink edge and a hard offset shadow with no blur (PLAN §4.0). Every card, chip and
    /// button that lifts off the page uses this.
    public func printed(
      fill: TegolaRole = .surfaceRaised,
      radius: Double = TegolaRadius.card,
      edge: Double = TegolaBorder.standard,
      shadow: Double = TegolaShadow.small,
      shadowRole: TegolaRole = .shadow
    ) -> some View {
      modifier(Printed(fill: fill, radius: radius, edge: edge, shadow: shadow, shadowRole: shadowRole))
    }

    /// Not yours: a dashed edge and no shadow, at every size, for wanted, borrowed and shared objects (D27, PD-062).
    /// The same dash marks a slot that invites ("+ Add a detail"); `DashedButton` is that use.
    public func notYours(radius: Double = TegolaRadius.card) -> some View {
      modifier(NotYours(radius: radius))
    }

    /// The halftone dots of a colour field or cover art. Only on colour fields, never on chrome (PLAN §4.0).
    public func halftone() -> some View {
      modifier(HalftoneOverlay())
    }
  }

  /// A rounded rectangle that becomes a true capsule once its radius reaches half the shorter side (the pill radius,
  /// 999). Continuous corners can't fit at that size and leave square fragments mid-edge, so pills and circles use
  /// circular ones.
  public struct PrintedShape: InsettableShape {
    let radius: Double
    var inset: Double = 0

    public init(radius: Double) {
      self.radius = radius
    }

    public func path(in rect: CGRect) -> Path {
      let rect = rect.insetBy(dx: inset, dy: inset)
      let half = min(rect.width, rect.height) / 2
      let corner = max(0, radius - inset)
      if corner >= half { return Capsule(style: .circular).path(in: rect) }
      return RoundedRectangle(cornerRadius: corner, style: .continuous).path(in: rect)
    }

    public func inset(by amount: CGFloat) -> PrintedShape {
      var copy = self
      copy.inset += amount
      return copy
    }
  }

  struct Printed: ViewModifier {
    let fill: TegolaRole
    let radius: Double
    let edge: Double
    let shadow: Double
    let shadowRole: TegolaRole
    @Environment(\.tegolaTheme) private var theme

    func body(content: Content) -> some View {
      let shape = PrintedShape(radius: radius)
      content
        .background(shape.fill(theme[fill].color))
        .clipShape(shape)
        .overlay(shape.strokeBorder(theme[.edge].color, lineWidth: edge))
        .background(shape.fill(theme[shadowRole].color).offset(x: shadow, y: shadow))
    }
  }

  struct NotYours: ViewModifier {
    let radius: Double
    @Environment(\.tegolaTheme) private var theme

    func body(content: Content) -> some View {
      content.overlay(
        PrintedShape(radius: radius)
          .strokeBorder(
            theme[.edgeNotYours].color,
            style: StrokeStyle(lineWidth: TegolaBorder.standard, dash: TegolaBorder.dash.map { CGFloat($0) })
          )
      )
    }
  }

  struct HalftoneOverlay: ViewModifier {
    @Environment(\.tegolaTheme) private var theme

    func body(content: Content) -> some View {
      let ink = theme.halftone.color
      return content.overlay(
        Canvas { context, size in
          let step = TegolaMetrics.halftoneSpacing
          let dot = TegolaMetrics.halftoneDot * 2
          var y = step / 2
          while y < size.height {
            var x = step / 2
            while x < size.width {
              context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: .color(ink))
              x += step
            }
            y += step
          }
        }
        .opacity(theme.halftoneOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      )
    }
  }
#endif

#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaDesignTokens

  /// A type's flat hero: its two tints at 150°, halftone dots and its mark (PD-145: no 3D; the README's
  /// `linear-gradient(150deg, a, b)`). The object hero without a photo, the collection tile's top and a row's thumbnail.
  public struct TypeTint: View {
    let gradient: [String]
    let mark: String
    let markStyle: TegolaTextStyle
    /// Space kept clear under the mark, for a panel that overlaps the hero's foot (the object screen).
    let bottomInset: Double
    @Environment(\.tegolaTheme) private var theme

    public init(
      gradient: [String],
      mark: String,
      markStyle: TegolaTextStyle = TegolaType.typeMark,
      bottomInset: Double = 0
    ) {
      self.gradient = gradient
      self.mark = mark
      self.markStyle = markStyle
      self.bottomInset = bottomInset
    }

    public var body: some View {
      let colours = (gradient.isEmpty ? ["sand"] : gradient).map { theme.tint(named: $0).color }
      LinearGradient(
        colors: colours.count == 1 ? [colours[0], colours[0]] : colours,
        startPoint: UnitPoint(x: 0.25, y: 0.07),
        endPoint: UnitPoint(x: 0.75, y: 0.93)
      )
      .halftone()
      .overlay(alignment: .bottomLeading) {
        Text(verbatim: mark)
          .tegolaTextStyle(markStyle)
          .foregroundStyle(TegolaRole.text)
          .opacity(0.9)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .padding(.horizontal, markStyle.size * 0.35)
          .padding(.bottom, markStyle.size * 0.2 + bottomInset)
          .accessibilityHidden(true)
      }
    }
  }

  /// A collection on the Shelf home (board 01): the type's tint with a count badge and mark on top, the name and a
  /// mono meta line under a 2.5 pt rule. The same shape for every type (F3).
  public struct CollectionTile: View {
    let name: Text
    let meta: Text
    let count: Int
    let gradient: [String]
    let mark: String
    @Environment(\.tegolaTheme) private var theme

    public init(name: Text, meta: Text, count: Int, gradient: [String], mark: String) {
      self.name = name
      self.meta = meta
      self.count = count
      self.gradient = gradient
      self.mark = mark
    }

    public var body: some View {
      VStack(spacing: 0) {
        TypeTint(gradient: gradient, mark: mark)
          .frame(height: 120)
          .overlay(alignment: .topTrailing) {
            Text(count, format: .number)
              .tegolaTextStyle(TegolaType.metaSmall)
              .foregroundStyle(TegolaRole.textOnStage)
              .padding(.horizontal, 6)
              .padding(.vertical, 3)
              .background(RoundedRectangle(cornerRadius: TegolaRadius.badge).fill(theme[.surfaceStage].color))
              .padding(TegolaSpace.s)
          }
        Rectangle().fill(theme[.edge].color).frame(height: TegolaBorder.standard)
        VStack(alignment: .leading, spacing: 3) {
          name.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text).lineLimit(1)
          meta.tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta).lineLimit(1)
        }
        .padding(.horizontal, TegolaSpace.m)
        .padding(.vertical, TegolaSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .printed(radius: TegolaRadius.cardLarge, shadow: TegolaShadow.large)
      .accessibilityElement(children: .combine)
    }
  }

  /// A dashed tile: the wishlist (not yours, so no shadow) or an invitation (board 01's "+ New collection").
  public struct DashedTile: View {
    let title: Text
    let meta: Text?

    public init(title: Text, meta: Text? = nil) {
      self.title = title
      self.meta = meta
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: 3) {
        Spacer(minLength: 0)
        title.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
        if let meta {
          meta.tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta)
        }
      }
      .padding(TegolaSpace.m)
      .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
      .notYours(radius: TegolaRadius.cardLarge)
      .accessibilityElement(children: .combine)
    }
  }

  /// The banner under the Shelf home's title: "Catalogued · 482 objects" in cobalt with money off (board 01's
  /// `sellingOff` variant, PD-138), or the value in green with it on.
  public struct CountBanner: View {
    let eyebrow: Text
    let figure: Text
    let isMoney: Bool

    public init(eyebrow: Text, figure: Text, isMoney: Bool) {
      self.eyebrow = eyebrow
      self.figure = figure
      self.isMoney = isMoney
    }

    public var body: some View {
      let ink: TegolaRole = isMoney ? .onAccentConfirm : .onAccentInfo
      VStack(alignment: .leading, spacing: TegolaSpace.xxs) {
        eyebrow.tegolaTextStyle(TegolaType.meta).foregroundStyle(ink).opacity(0.85)
        figure.tegolaTextStyle(TegolaType.bigNumber).foregroundStyle(ink)
      }
      .padding(.horizontal, TegolaSpace.l)
      .padding(.vertical, TegolaSpace.m + 1)
      .frame(maxWidth: .infinity, alignment: .leading)
      .printed(fill: isMoney ? .accentConfirm : .accentInfo, radius: 16, shadow: TegolaShadow.large)
      .accessibilityElement(children: .combine)
    }
  }

  /// One object in a list (board 07, 10, 14): a thumbnail (the photo, or the type's tint and mark), the title, a mono
  /// meta line and an optional trailing chip. Not-yours objects get the dashed edge.
  public struct ObjectRow<Trailing: View>: View {
    let title: Text
    let meta: Text
    let gradient: [String]
    let mark: String
    let notYours: Bool
    let trailing: Trailing

    public init(
      title: Text,
      meta: Text,
      gradient: [String],
      mark: String,
      notYours: Bool = false,
      @ViewBuilder trailing: () -> Trailing
    ) {
      self.title = title
      self.meta = meta
      self.gradient = gradient
      self.mark = mark
      self.notYours = notYours
      self.trailing = trailing()
    }

    public var body: some View {
      HStack(spacing: TegolaSpace.m) {
        TypeTint(gradient: gradient, mark: mark, markStyle: TegolaType.metaSmall)
          .frame(width: 52, height: 52)
          .clipShape(RoundedRectangle(cornerRadius: TegolaRadius.badge))
          .overlay(RoundedRectangle(cornerRadius: TegolaRadius.badge).strokeBorder(lineWidth: TegolaBorder.standard))
          .foregroundStyle(TegolaRole.text)
        VStack(alignment: .leading, spacing: 3) {
          title.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text).lineLimit(2)
          meta.tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta).lineLimit(1)
        }
        Spacer(minLength: 0)
        trailing
      }
      .padding(TegolaSpace.s + 1)
      .frame(minHeight: TegolaMetrics.minimumHitTarget)
      .fixedSize(horizontal: false, vertical: true)
      .modifier(RowSurface(notYours: notYours))
      .accessibilityElement(children: .combine)
    }
  }

  extension ObjectRow where Trailing == EmptyView {
    public init(title: Text, meta: Text, gradient: [String], mark: String, notYours: Bool = false) {
      self.init(title: title, meta: meta, gradient: gradient, mark: mark, notYours: notYours) { EmptyView() }
    }
  }

  /// A small figure with its eyebrow (board 19's "Return rate 4 / 5", board 22's "Borrowed 6 things"). Two sit side by
  /// side and share the width.
  public struct StatTile: View {
    let eyebrow: Text
    let figure: Text
    let fill: TegolaRole

    public init(eyebrow: Text, figure: Text, fill: TegolaRole = .surfaceRaised) {
      self.eyebrow = eyebrow
      self.figure = figure
      self.fill = fill
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        eyebrow.tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta)
        figure.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
      }
      .padding(TegolaSpace.m)
      .frame(maxWidth: .infinity, alignment: .leading)
      .printed(fill: fill, radius: TegolaRadius.card)
      .accessibilityElement(children: .combine)
    }
  }

  struct RowSurface: ViewModifier {
    let notYours: Bool

    func body(content: Content) -> some View {
      if notYours {
        content.notYours(radius: TegolaRadius.card)
      } else {
        content.printed(radius: TegolaRadius.card)
      }
    }
  }
#endif

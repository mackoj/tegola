#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaDesignTokens

  // The bars are stickers on the page, never translucent slabs over it (board 29). The large title is
  // `ScreenHeader`; these are the other states.

  /// The bar once a screen scrolls, or on a pushed screen: a round back sticker, the title, an optional trailing
  /// accessory, over a 2.5 pt rule (board 29, state 2). On the dark stage the same geometry inverts (state 3).
  public struct CompactBar<Trailing: View>: View {
    let title: Text
    let onStage: Bool
    let back: (() -> Void)?
    let trailing: Trailing
    @Environment(\.tegolaTheme) private var theme

    public init(
      _ title: Text,
      onStage: Bool = false,
      back: (() -> Void)? = nil,
      @ViewBuilder trailing: () -> Trailing
    ) {
      self.title = title
      self.onStage = onStage
      self.back = back
      self.trailing = trailing()
    }

    public var body: some View {
      HStack(spacing: TegolaSpace.m) {
        if let back {
          Button(action: back) {
            Image(systemName: "chevron.left")
              .resizable()
              .scaledToFit()
              .fontWeight(.bold)
              .frame(width: 9, height: 15)
              .foregroundStyle(onStage ? TegolaRole.textOnStage : TegolaRole.text)
              .frame(width: TegolaMetrics.minimumHitTarget, height: TegolaMetrics.minimumHitTarget)
              .overlay(
                Circle().strokeBorder(theme[onStage ? .textOnStage : .edge].color, lineWidth: TegolaBorder.standard)
              )
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Text("Back", bundle: .module))
        }
        title
          .tegolaTextStyle(onStage ? TegolaType.meta : TegolaType.heading)
          .foregroundStyle(onStage ? TegolaRole.accentHighlight : TegolaRole.text)
          .lineLimit(1)
        Spacer(minLength: 0)
        trailing
      }
      .padding(.horizontal, TegolaSpace.gutter)
      .padding(.vertical, TegolaSpace.s)
      .background(theme[onStage ? .surfaceStage : .surface].color)
      .overlay(alignment: .bottom) {
        Rectangle().fill(theme[.edge].color).frame(height: TegolaBorder.standard)
      }
    }
  }

  extension CompactBar where Trailing == EmptyView {
    public init(_ title: Text, onStage: Bool = false, back: (() -> Void)? = nil) {
      self.init(title, onStage: onStage, back: back) { EmptyView() }
    }
  }

  /// The bar inside a modal: Close or Cancel on the left, never Back; the mono title in the middle; Save on the right
  /// (board 29, state 4). A modal is its own world, so leaving it takes the whole world with it.
  public struct ModalBar: View {
    let title: Text
    let dismissLabel: Text
    let saveLabel: Text?
    let dismiss: () -> Void
    let save: (() -> Void)?
    let canSave: Bool
    @Environment(\.tegolaTheme) private var theme

    public init(
      _ title: Text,
      dismissLabel: Text,
      dismiss: @escaping () -> Void,
      saveLabel: Text? = nil,
      canSave: Bool = true,
      save: (() -> Void)? = nil
    ) {
      self.title = title
      self.dismissLabel = dismissLabel
      self.dismiss = dismiss
      self.saveLabel = saveLabel
      self.canSave = canSave
      self.save = save
    }

    public var body: some View {
      ZStack {
        title.tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        HStack {
          Button(action: dismiss) {
            dismissLabel.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.accentLoss)
              .frame(minWidth: TegolaMetrics.minimumHitTarget, minHeight: TegolaMetrics.minimumHitTarget)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("modal.dismiss")
          Spacer()
          if let save, let saveLabel {
            Button(action: save) {
              saveLabel.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.accentConfirm)
                .frame(minWidth: TegolaMetrics.minimumHitTarget, minHeight: TegolaMetrics.minimumHitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("modal.save")
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
          }
        }
      }
      .padding(.horizontal, TegolaSpace.gutter)
      .padding(.vertical, TegolaSpace.xs)
      .background(theme[.surfaceSunken].color)
      .overlay(alignment: .bottom) {
        Rectangle().fill(theme[.edge].color).frame(height: TegolaBorder.standard)
      }
    }
  }

  /// One tab in the bar.
  public struct TabBarItem: Identifiable, Sendable {
    public let id: String
    public let label: Text

    public init(id: String, label: Text) {
      self.id = id
      self.label = label
    }
  }

  /// The tab bar (board 01, board 29 state 5): four tabs and a raised scan button in the middle slot, which presents
  /// rather than navigates. Active tabs are full opacity with an orange glyph, inactive ones at 0.45.
  public struct TegolaTabBar: View {
    let leading: [TabBarItem]
    let trailing: [TabBarItem]
    let selected: String
    let scanLabel: Text
    let select: (String) -> Void
    let scan: () -> Void
    @Environment(\.tegolaTheme) private var theme

    public init(
      leading: [TabBarItem],
      trailing: [TabBarItem],
      selected: String,
      scanLabel: Text,
      select: @escaping (String) -> Void,
      scan: @escaping () -> Void
    ) {
      self.leading = leading
      self.trailing = trailing
      self.selected = selected
      self.scanLabel = scanLabel
      self.select = select
      self.scan = scan
    }

    public var body: some View {
      HStack(alignment: .top, spacing: 0) {
        ForEach(leading) { tab($0) }
        scanButton
        ForEach(trailing) { tab($0) }
      }
      .padding(.top, TegolaSpace.s)
      .padding(.horizontal, TegolaSpace.xs)
      .frame(height: TegolaMetrics.tabBarHeight, alignment: .top)
      .frame(maxWidth: .infinity)
      .background(theme[.surface].color)
      .overlay(alignment: .top) {
        Rectangle().fill(theme[.edge].color).frame(height: TegolaBorder.standard)
      }
    }

    func tab(_ item: TabBarItem) -> some View {
      let isSelected = item.id == selected
      return Button {
        select(item.id)
      } label: {
        VStack(spacing: TegolaSpace.xxs + 2) {
          RoundedRectangle(cornerRadius: TegolaRadius.glyph)
            .fill(theme[isSelected ? .accentAction : .surface].color)
            .overlay(
              RoundedRectangle(cornerRadius: TegolaRadius.glyph)
                .strokeBorder(theme[.edge].color, lineWidth: TegolaBorder.standard)
            )
            .frame(width: 26, height: 22)
          item.label
            .tegolaTextStyle(TegolaType.metaSmall)
            .foregroundStyle(TegolaRole.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .opacity(isSelected ? 1 : 0.45)
        .frame(maxWidth: .infinity, minHeight: TegolaMetrics.minimumHitTarget)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
      .accessibilityIdentifier("tab.\(item.id)")
    }

    var scanButton: some View {
      Button(action: scan) {
        Image(systemName: "plus")
          .resizable()
          .scaledToFit()
          .fontWeight(.black)
          .frame(width: 18, height: 18)
          .foregroundStyle(TegolaRole.onAccentHighlight)
          .frame(width: TegolaMetrics.scanButtonDiameter + 12, height: TegolaMetrics.scanButtonDiameter + 12)
          .printed(fill: .accentHighlight, radius: TegolaRadius.pill, shadow: TegolaShadow.small)
          .frame(maxWidth: .infinity, minHeight: TegolaMetrics.minimumHitTarget)
          .offset(y: -TegolaMetrics.scanButtonRaise - TegolaSpace.s)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(scanLabel)
      .accessibilityIdentifier("tab.scan")
    }
  }
#endif

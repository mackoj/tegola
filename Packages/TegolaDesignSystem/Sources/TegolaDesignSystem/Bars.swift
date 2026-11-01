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
  /// Its words are the shared actions' (`TegolaAction`): **Close** to leave, or **Cancel** when there's a **Save**.
  public struct ModalBar: View {
    let title: Text
    let leaving: TegolaAction
    let dismiss: () -> Void
    let save: (() -> Void)?
    let canSave: Bool
    @Environment(\.tegolaTheme) private var theme

    /// `leaving` defaults to Close, or to Cancel when the bar has a Save.
    public init(
      _ title: Text,
      leaving: TegolaAction? = nil,
      dismiss: @escaping () -> Void,
      canSave: Bool = true,
      save: (() -> Void)? = nil
    ) {
      self.title = title
      self.leaving = leaving ?? (save == nil ? .close : .cancel)
      self.dismiss = dismiss
      self.canSave = canSave
      self.save = save
    }

    public var body: some View {
      ZStack {
        title.tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        HStack {
          Button(action: dismiss) {
            leaving.label.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.accentLoss)
              .frame(minWidth: TegolaMetrics.minimumHitTarget, minHeight: TegolaMetrics.minimumHitTarget)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("modal.dismiss")
          Spacer()
          if let save {
            Button(action: save) {
              TegolaAction.save.label.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.accentConfirm)
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
#endif

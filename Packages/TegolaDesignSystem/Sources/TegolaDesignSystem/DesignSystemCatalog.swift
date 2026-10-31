#if canImport(SwiftUI)
  public import SwiftUI
  import TegolaDesignTokens

  /// Every component in every variant, on one page per section (PLAN §2.6). The snapshot tests render each section,
  /// and those PNGs are the milestone's component screenshots. Sample words are specimens, not UI copy, so they're
  /// verbatim.
  public enum DesignSystemCatalog {
    public enum Section: String, CaseIterable, Sendable {
      case titles, buttons, pills, chips, surfaces, empty, bars, tabBar
    }

    @MainActor @ViewBuilder
    public static func view(_ section: Section) -> some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        switch section {
        case .titles: titles
        case .buttons: buttons
        case .pills: pills
        case .chips: chips
        case .surfaces: surfaces
        case .empty: empty
        case .bars: bars
        case .tabBar: tabBar
        }
      }
      .padding(section == .bars || section == .tabBar ? 0 : TegolaSpace.gutter)
      .frame(width: 393, alignment: .topLeading)
      .background(TegolaTheme.board[.surface].color)
    }

    static func t(_ text: String) -> Text { Text(verbatim: text) }

    @MainActor static var titles: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.xl) {
        ScreenHeader(eyebrow: t("Tuesday · 482 objects"), title: [t("My"), t("Collections")]) {
          t("TM").tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.onAccentHighlight)
            .frame(width: 62, height: 62)
            .printed(fill: .accentHighlight, radius: TegolaRadius.pill)
        }
        ScreenHeader(
          eyebrow: t("B1 · Chrome"),
          title: [t("Our bars,"), t("not the"), t("system's")],
          body: t("Five states, one rule: the bar is a sticker sitting on the page.")
        )
        DisplayTitle([t("Nothing on the"), t("shelf yet")], style: TegolaType.displaySmall)
      }
    }

    @MainActor static var buttons: some View {
      VStack(spacing: TegolaSpace.m) {
        ForEach(TegolaButtonStyle.Kind.allCases, id: \.self) { kind in
          Button {
          } label: {
            t("\(kind)".capitalized)
          }.buttonStyle(.tegola(kind))
        }
        Button {
        } label: {
          t("Disabled")
        }.buttonStyle(.tegola(.accent)).disabled(true)
        ButtonPair {
          Button {
          } label: {
            t("Cancel")
          }.buttonStyle(.tegola(.secondary))
        } trailing: {
          Button {
          } label: {
            t("Save")
          }.buttonStyle(.tegola(.confirm))
        }
        DashedButton(t("+ Add a detail")) {}
      }
    }

    @MainActor static var pills: some View {
      HStack(spacing: TegolaSpace.s) {
        Pill(t("All"), isActive: true) {}
        Pill(t("Lent out · 4"), isActive: false) {}
        Pill(t("Grails"), isActive: false) {}
      }
    }

    @MainActor static var chips: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.m) {
        HStack(spacing: TegolaSpace.s) {
          ForEach(StatusSwatch.allCases, id: \.self) { swatch in
            StatusChip(swatch, label: t(swatch.rawValue))
          }
        }
        HStack(spacing: TegolaSpace.s) {
          Chip(t("Grail"), fill: .accentGrail, ink: .onAccentGrail, tilt: -4)
          Chip(t("Jazz"), fill: .accentHighlight, ink: .onAccentHighlight)
          Chip(t("×3"))
        }
      }
    }

    @MainActor static var surfaces: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        VStack(alignment: .leading, spacing: TegolaSpace.xs) {
          t("Estimated value").tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.onAccentConfirm)
          t("€14,280").tegolaTextStyle(TegolaType.bigNumber).foregroundStyle(TegolaRole.onAccentConfirm)
        }
        .padding(TegolaSpace.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printed(fill: .accentConfirm, radius: TegolaRadius.cardLarge, shadow: TegolaShadow.large)
        t("33⅓").tegolaTextStyle(TegolaType.typeMark).foregroundStyle(TegolaRole.text)
          .padding(TegolaSpace.l)
          .frame(maxWidth: .infinity, minHeight: 120, alignment: .bottomLeading)
          .background(TegolaTheme.board[.accentConfirm].color)
          .halftone()
          .printed(fill: .accentConfirm, radius: TegolaRadius.cardLarge, shadow: TegolaShadow.large)
        t("Wanted: not yours yet").tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
          .padding(TegolaSpace.l)
          .frame(maxWidth: .infinity, alignment: .leading)
          .notYours()
      }
    }

    @MainActor static var empty: some View {
      EmptyState(
        title: [t("Nothing on the"), t("shelf yet")],
        message: t("Start with the piece you'd save in a fire.")
      ) {
        Button {
        } label: {
          t("Type it")
        }.buttonStyle(.tegola(.primary))
      }
    }

    @MainActor static var bars: some View {
      VStack(spacing: TegolaSpace.l) {
        CompactBar(t("Malibu — Anderson .Paak"), back: {})
        CompactBar(t("On the stage"), onStage: true, back: {}) {
          Button {
          } label: {
            t("Share")
          }.buttonStyle(.tegola(.secondary)).fixedSize()
        }
        ModalBar(t("Lend sheet"), dismissLabel: t("Close"), dismiss: {}, saveLabel: t("Save"), save: {})
      }
    }

    @MainActor static var tabBar: some View {
      TegolaTabBar(
        leading: [.init(id: "shelf", label: t("Shelf")), .init(id: "find", label: t("Find"))],
        trailing: [.init(id: "activity", label: t("Activity")), .init(id: "you", label: t("You"))],
        selected: "shelf",
        scanLabel: t("Scan"),
        select: { _ in },
        scan: {}
      )
      .padding(.top, TegolaSpace.l)
    }
  }

  #Preview("Catalog") {
    ScrollView {
      VStack(spacing: 0) {
        ForEach(DesignSystemCatalog.Section.allCases, id: \.self) { DesignSystemCatalog.view($0) }
      }
    }
  }
#endif

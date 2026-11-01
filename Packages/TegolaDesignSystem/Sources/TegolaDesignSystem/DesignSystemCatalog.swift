#if canImport(SwiftUI)
  public import SwiftUI
  import TegolaDesignTokens

  /// Every component in every variant, on one page per section (PLAN §2.6). The snapshot tests render each section,
  /// and those PNGs are the milestone's component screenshots. Sample words are specimens, not UI copy, so they're
  /// verbatim.
  public enum DesignSystemCatalog {
    public enum Section: String, CaseIterable, Sendable {
      case titles, buttons, actions, pills, chips, surfaces, tiles, rows, empty, bars
    }

    @MainActor @ViewBuilder
    public static func view(_ section: Section) -> some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        switch section {
        case .titles: titles
        case .buttons: buttons
        case .actions: actions
        case .pills: pills
        case .chips: chips
        case .surfaces: surfaces
        case .tiles: tiles
        case .rows: rows
        case .empty: empty
        case .bars: bars
        }
      }
      .padding(section == .bars ? 0 : TegolaSpace.gutter)
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

    @MainActor static var tiles: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.l) {
        CountBanner(eyebrow: t("Catalogued"), figure: t("482 objects"), isMoney: false)
        CountBanner(eyebrow: t("Estimated value"), figure: t("€14,280"), isMoney: true)
        HStack(spacing: TegolaSpace.m) {
          StatTile(eyebrow: t("RETURN RATE"), figure: t("4 / 5"), fill: .statusFine)
          StatTile(eyebrow: t("AVERAGE OUT"), figure: t("18 days"))
        }
        HStack(alignment: .top, spacing: TegolaSpace.m) {
          CollectionTile(
            name: t("My Music"),
            meta: t("128 releases · 2 lent"),
            count: 128,
            gradient: ["teal", "cobalt"],
            mark: "33⅓"
          )
          CollectionTile(
            name: t("The Library"),
            meta: t("92 games"),
            count: 92,
            gradient: ["oxide", "ink"],
            mark: "CIB"
          )
        }
        HStack(alignment: .top, spacing: TegolaSpace.m) {
          CollectionTile(
            name: t("Things"),
            meta: t("18 things"),
            count: 18,
            gradient: ["indigo", "claret"],
            mark: "00"
          )
          DashedTile(title: t("Wishlist"), meta: t("3 wanted"))
        }
      }
    }

    @MainActor static var rows: some View {
      VStack(spacing: TegolaSpace.m) {
        ObjectRow(
          title: t("Radiant Silvergun"),
          meta: t("Sega Saturn · 1998"),
          gradient: ["oxide", "ink"],
          mark: "CIB"
        ) {
          Chip(t("Grail"), fill: .accentGrail, ink: .onAccentGrail)
        }
        ObjectRow(title: t("Kid A"), meta: t("Radiohead · Vinyl"), gradient: ["teal", "cobalt"], mark: "33⅓") {
          StatusChip(.watch, label: t("Lent"))
        }
        ObjectRow(
          title: t("Policenauts"),
          meta: t("PlayStation · wanted"),
          gradient: ["oxide", "ink"],
          mark: "CIB",
          notYours: true
        )
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
        ModalBar(t("Lend sheet"), dismiss: {})
        ModalBar(t("Edit"), dismiss: {}, save: {})
      }
    }

    /// Every shared action (D-77): its item (symbol and words, as a tab shows it) and its button in its usual look.
    @MainActor static var actions: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        ForEach(TegolaAction.allCases, id: \.self) { action in
          HStack(spacing: TegolaSpace.m) {
            action.item
              .tegolaTextStyle(TegolaType.label)
              .foregroundStyle(TegolaRole.text)
              .frame(width: 150, alignment: .leading)
            ActionButton(action, id: "catalog.\(action.rawValue)") {}
          }
        }
      }
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

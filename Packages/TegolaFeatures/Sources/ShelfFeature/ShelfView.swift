#if canImport(SwiftUI)
  public import ComposableArchitecture
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  @ViewAction(for: ShelfFeature.self)
  public struct ShelfView: View {
    public let store: StoreOf<ShelfFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<ShelfFeature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: TegolaSpace.xl) {
          ScreenHeader(
            eyebrow: Text(store.now, format: .dateTime.weekday(.wide)),
            title: [Text("My", bundle: .module), Text("Collections", bundle: .module)]
          )
          if store.isEmpty {
            empty
          } else {
            content(store.summary)
          }
        }
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.top, TegolaSpace.l)
        .padding(.bottom, TegolaSpace.xxl)
      }
      .background(theme[.surface].color)
      .onAppear { send(.onAppear) }
    }

    /// Board 02, as F2 has it: **Scan your first object**, the first piece's camera, and **Bring your list**, Add's
    /// import. **Type it** stays for a collector who'd rather not use the camera. No sample data (PD-102).
    var empty: some View {
      EmptyState(
        title: [Text("Nothing on the", bundle: .module), Text("shelf yet", bundle: .module)],
        message: Text("Start with one piece you love, and the shelf grows from there.", bundle: .module)
      ) {
        VStack(spacing: TegolaSpace.s) {
          Button {
            send(.scanFirstObjectTapped)
          } label: {
            Text("Scan your first object", bundle: .module)
          }
          .buttonStyle(.tegola(.accent))
          .accessibilityIdentifier("shelf.scanFirst")
          Button {
            send(.typeItTapped)
          } label: {
            Text("Type it", bundle: .module)
          }
          .buttonStyle(.tegola(.secondary))
          .accessibilityIdentifier("shelf.typeIt")
          Button {
            send(.bringListTapped)
          } label: {
            Text("Bring your list", bundle: .module)
          }
          .buttonStyle(.tegola(.secondary))
          .accessibilityIdentifier("shelf.bringList")
        }
      }
    }

    @ViewBuilder
    func content(_ summary: ShelfSummary) -> some View {
      if let value = summary.value {
        CountBanner(
          eyebrow: Text("Estimated value", bundle: .module),
          figure: Text(value.map(\.formatted).joined(separator: " · ")),
          isMoney: true
        )
      } else {
        CountBanner(
          eyebrow: Text("Catalogued", bundle: .module),
          figure: Text("\(summary.count) objects", bundle: .module),
          isMoney: false
        )
      }
      if !summary.today.lines.isEmpty {
        TodayStripView(
          lines: summary.today.lines,
          openSignals: { send(.needAttentionTapped) },
          openReview: { send(.toTidyTapped) }
        )
      }
      if store.offersNotifications {
        notificationOffer
      }
      if summary.showsPlaces {
        Button {
          send(.placesTapped)
        } label: {
          HStack {
            Text("Places", bundle: .module).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
            Spacer()
            Text(store.snapshot.shelf.livePlaces.count, format: .number)
              .tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
          }
          .padding(TegolaSpace.m)
          .frame(minHeight: TegolaMetrics.minimumHitTarget)
          .printed(radius: TegolaRadius.card)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("shelf.places")
      }
      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: TegolaSpace.m), GridItem(.flexible(), spacing: TegolaSpace.m)],
        spacing: TegolaSpace.l
      ) {
        ForEach(summary.collections) { line in
          Button {
            send(.collectionTapped(line.id))
          } label: {
            tile(line)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("shelf.collection.\(line.name)")
        }
        if summary.wanted > 0 {
          DashedTile(
            title: Text("Wishlist", bundle: .module),
            meta: Text("\(summary.wanted) wanted", bundle: .module)
          )
        }
      }
    }

    func tile(_ line: ShelfSummary.CollectionLine) -> some View {
      let manifest = line.typeID.flatMap { catalogue.manifest($0) }
      let noun = manifest?.name.noun(for: line.count).lowercased() ?? String(localized: "objects", bundle: .module)
      let meta =
        line.lent > 0
        ? Text("\(line.count) \(noun) · \(line.lent) lent", bundle: .module)
        : Text(verbatim: "\(line.count.formatted()) \(noun)")
      return CollectionTile(
        name: Text(verbatim: line.name),
        meta: meta,
        count: line.count,
        gradient: manifest?.gradient ?? [],
        mark: manifest?.mark ?? "MIX"
      )
    }
  }

  extension ShelfView {
    /// The clock notification offer (F15): once, in plain words. Either answer puts it away for good.
    var notificationOffer: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        Text("A nudge when something's due?", bundle: .module)
          .tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.onAccentHighlight)
        Text(
          "Some things on your shelf wear out with time, like a game's save battery. Tegola can send a notification when one is probably due.",
          bundle: .module
        )
        .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.onAccentHighlight)
        ButtonPair {
          Button {
            send(.notificationsAccepted)
          } label: {
            Text("Yes, tell me", bundle: .module)
          }
          .buttonStyle(.tegola(.primary))
          .accessibilityIdentifier("shelf.notifications.accept")
        } trailing: {
          Button {
            send(.notificationsDeclined)
          } label: {
            Text("No thanks", bundle: .module)
          }
          .buttonStyle(.tegola(.secondary))
          .accessibilityIdentifier("shelf.notifications.decline")
        }
      }
      .padding(TegolaSpace.l)
      .printed(fill: .accentHighlight, radius: TegolaRadius.card)
    }
  }

  /// The Today strip: one line per non-empty count, never a zero (F3, PD-140).
  struct TodayStripView: View {
    let lines: [TodayStrip.Line]
    /// "Need attention" opens the signal feed (journey 5).
    let openSignals: () -> Void
    /// "To tidy" opens the review queue (F8).
    let openReview: () -> Void

    var body: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        Text("Today", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        ForEach(lines, id: \.self) { line in
          if case .toTidy = line {
            Button(action: openReview) {
              HStack {
                text(line).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
                Spacer()
                Text(verbatim: "→").tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.textMuted)
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("today.toTidy")
          } else if case .needAttention = line {
            Button(action: openSignals) {
              HStack {
                text(line).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
                Spacer()
                Text(verbatim: "→").tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.textMuted)
              }
              // The whole line is the button, not just the words and the arrow.
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("today.needAttention")
          } else {
            text(line).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
          }
        }
      }
      .padding(TegolaSpace.l)
      .frame(maxWidth: .infinity, alignment: .leading)
      .printed(fill: .accentHighlight, radius: TegolaRadius.card)
      // Contain, not combine: "need attention" is a button of its own, and combining would swallow its tap.
      .accessibilityElement(children: .contain)
    }

    func text(_ line: TodayStrip.Line) -> Text {
      switch line {
      case .toTidy(let n): Text("\(n) to tidy", bundle: .module)
      case .needAttention(let n): Text("\(n) need attention", bundle: .module)
      case .overdue(let n): Text("\(n) overdue", bundle: .module)
      }
    }
  }

  extension Money {
    var formatted: String {
      amount.formatted(.currency(code: currency.code))
    }
  }

  #Preview("Seeded") {
    let _ = prepareDependencies { try! $0.bootstrapDatabase(seed: true) }
    ShelfView(store: Store(initialState: ShelfFeature.State()) { ShelfFeature() })
  }

  #Preview("Empty") {
    let _ = prepareDependencies { try! $0.bootstrapDatabase(reset: true) }
    ShelfView(store: Store(initialState: ShelfFeature.State()) { ShelfFeature() })
  }
#endif

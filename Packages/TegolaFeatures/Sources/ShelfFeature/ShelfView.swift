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

    var empty: some View {
      EmptyState(
        title: [Text("Nothing on the", bundle: .module), Text("shelf yet", bundle: .module)],
        message: Text("Start with one piece you love. Type it in, and the shelf grows from there.", bundle: .module)
      ) {
        Button {
          send(.typeItTapped)
        } label: {
          Text("Type it", bundle: .module)
        }
        .buttonStyle(.tegola(.accent))
        .accessibilityIdentifier("shelf.typeIt")
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
        TodayStripView(lines: summary.today.lines) { send(.needAttentionTapped) }
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

    var body: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        Text("Today", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        ForEach(lines, id: \.self) { line in
          if case .needAttention = line {
            Button(action: openSignals) {
              HStack {
                text(line).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
                Spacer()
                Text(verbatim: "→").tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.textMuted)
              }
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
      .accessibilityElement(children: .combine)
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

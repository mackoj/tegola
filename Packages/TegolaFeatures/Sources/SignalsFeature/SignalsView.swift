#if canImport(SwiftUI)
  public import ComposableArchitecture
  import ShelfViews
  public import SwiftUI
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel

  @ViewAction(for: SignalsFeature.self)
  public struct SignalsView: View {
    public let store: StoreOf<SignalsFeature>
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<SignalsFeature>) {
      self.store = store
    }

    public var body: some View {
      let feed = store.feed
      ScrollView {
        VStack(alignment: .leading, spacing: TegolaSpace.l) {
          ScreenHeader(title: [Text("Need attention", bundle: .module)])
          if feed.isEmpty {
            Text("Nothing needs you right now.", bundle: .module)
              .tegolaTextStyle(TegolaType.body)
              .foregroundStyle(TegolaRole.textMuted)
          }
          ForEach(feed.map { (id: "\($0.object.id)/\($0.signal.clock)", entry: $0) }, id: \.id) { row in
            let entry = row.entry
            Button {
              send(.objectTapped(entry.object.id))
            } label: {
              SignalRow(title: entry.object.title, signal: entry.signal)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("signals.row.\(entry.object.title)")
          }
        }
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.vertical, TegolaSpace.l)
      }
      .background(theme[.surface].color)
    }
  }

  /// One signal: the object, the clock's chip in its swatch, and the reason labelled Estimate.
  struct SignalRow: View {
    let title: String
    let signal: Signal

    var body: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        HStack(alignment: .firstTextBaseline) {
          Text(verbatim: title).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
          Spacer(minLength: TegolaSpace.s)
          StatusChip(signal.status.swatch, label: signal.title)
        }
        EstimateLabel()
        signal.reasonText.tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
      }
      .padding(TegolaSpace.l)
      .frame(maxWidth: .infinity, alignment: .leading)
      .printed(fill: .surfaceRaised, radius: TegolaRadius.card)
    }
  }
#endif

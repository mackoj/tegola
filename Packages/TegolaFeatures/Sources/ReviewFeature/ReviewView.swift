#if canImport(SwiftUI)
  public import ComposableArchitecture
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  /// The review queue (F8): strong matches with **Confirm all**, then the ones to look at, then what's as written.
  @ViewAction(for: ReviewFeature.self)
  public struct ReviewView: View {
    @Bindable public var store: StoreOf<ReviewFeature>
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<ReviewFeature>) {
      self.store = store
    }

    public var body: some View {
      let review = store.review
      ScrollView {
        VStack(alignment: .leading, spacing: TegolaSpace.xl) {
          ScreenHeader(
            eyebrow: Text("\(review.rows.count) to confirm", bundle: .module),
            title: [Text("Review", bundle: .module)]
          )
          if review.rows.isEmpty {
            Text("Nothing to confirm. Everything on the shelf is yours as it is.", bundle: .module)
              .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
          }
          section(.strong, review)
          section(.maybe, review)
          section(.asWritten, review)
        }
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.vertical, TegolaSpace.l)
      }
      .background(theme[.surface].color)
      .onAppear { send(.onAppear) }
    }

    @ViewBuilder
    func section(_ group: ReviewQueue.Group, _ review: ReviewQueue) -> some View {
      let rows = review.rows(in: group)
      if !rows.isEmpty {
        VStack(alignment: .leading, spacing: TegolaSpace.m) {
          HStack {
            heading(group, count: rows.count).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
            Spacer()
            if group == .strong {
              Button {
                send(.confirmAllTapped)
              } label: {
                Text("Confirm all", bundle: .module)
              }
              .buttonStyle(.tegola(.quiet))
              .accessibilityIdentifier("review.confirmAll")
            }
          }
          ForEach(rows) { row in card(row) }
        }
      }
    }

    func heading(_ group: ReviewQueue.Group, count: Int) -> Text {
      switch group {
      case .strong: Text("\(count) strong matches", bundle: .module)
      case .maybe: Text("\(count) to look at", bundle: .module)
      case .asWritten: Text("\(count) as you wrote them", bundle: .module)
      }
    }

    func card(_ row: ReviewQueue.Row) -> some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        Group {
          if row.object.title.isEmpty {
            Text("Needs details", bundle: .module)
          } else {
            Text(verbatim: row.object.title)
          }
        }
        .tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
        if let candidate = row.candidates.first, !row.asks {
          proposal(candidate)
        }
        if row.asks {
          Text("Which one?", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
          FlowLayout(spacing: TegolaSpace.xs) {
            ForEach(row.candidates, id: \.releaseID) { candidate in
              Pill(title(candidate), isActive: store.picked[row.id] == candidate.releaseID) {
                send(.candidatePicked(row.id, releaseID: candidate.releaseID))
              }
            }
          }
        }
        if let alike = row.lookAlikes, alike.asks, let yours = alike.owned.first {
          // F7: said unprompted, never merged.
          HStack {
            Text("You already have this one.", bundle: .module)
              .tegolaTextStyle(TegolaType.bodySmall).foregroundStyle(TegolaRole.text)
            Spacer()
            Button {
              send(.openYoursTapped(yours))
            } label: {
              Text("Open yours", bundle: .module)
            }
            .buttonStyle(.tegola(.quiet))
          }
          .padding(TegolaSpace.s)
          .printed(fill: .accentHighlight, radius: TegolaRadius.input, shadow: 0)
        }
        ButtonPair {
          Button {
            send(.confirmTapped(row.id))
          } label: {
            Text("Confirm", bundle: .module)
          }
          .buttonStyle(.tegola(.confirm))
          .accessibilityIdentifier("review.confirm.\(row.object.title)")
        } trailing: {
          Button {
            send(.fillInTapped(row.id))
          } label: {
            Text("Fill in", bundle: .module)
          }
          .buttonStyle(.tegola(.secondary))
        }
      }
      .padding(TegolaSpace.l)
      .frame(maxWidth: .infinity, alignment: .leading)
      .printed(radius: TegolaRadius.card)
    }

    func title(_ candidate: LookupCandidate) -> Text {
      var parts: [String] = []
      if case .text(let title) = candidate.values[.title] { parts.append(title) }
      if case .year(let year) = candidate.values[.year] { parts.append(String(year)) }
      if let subtype = candidate.subtype { parts.append(subtype) }
      return Text(verbatim: parts.joined(separator: " · "))
    }

    /// What confirming fills, and why it was proposed (PD-150).
    func proposal(_ candidate: LookupCandidate) -> some View {
      VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        title(candidate).tegolaTextStyle(TegolaType.label).foregroundStyle(TegolaRole.text)
        HStack(spacing: TegolaSpace.xs) {
          ForEach(candidate.reasons, id: \.self) { reason in Chip(reasonText(reason)) }
          Chip(strength(candidate.strength))
        }
        if let source = candidate.sources.first {
          Text(verbatim: source.attribution ?? source.name)
            .tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta)
        }
      }
    }

    func strength(_ strength: LookupCandidate.Strength) -> Text {
      switch strength {
      case .strong: Text("Strong", bundle: .module)
      case .likely: Text("Likely", bundle: .module)
      case .weak: Text("Weak", bundle: .module)
      }
    }

    func reasonText(_ reason: LookupCandidate.Reason) -> Text {
      switch reason {
      case .barcode: Text("Barcode", bundle: .module)
      case .catalogueNumber: Text("Catalogue number", bundle: .module)
      case .title: Text("Title", bundle: .module)
      case .ocr: Text("Label text", bundle: .module)
      case .image: Text("Photo", bundle: .module)
      case .region: Text("Region", bundle: .module)
      case .subtype: Text("Platform", bundle: .module)
      case .typoCorrected: Text("Typo corrected", bundle: .module)
      case .bundleSplit: Text("Bundle split", bundle: .module)
      }
    }
  }
#endif

#if canImport(SwiftUI)
  public import ComposableArchitecture
  import ShelfViews
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  /// F14: which card, a preview of it, and the system share sheet with the card as an image.
  @ViewAction(for: ShareFeature.self)
  public struct ShareView: View {
    @Bindable public var store: StoreOf<ShareFeature>
    @Dependency(\.catalogue) var catalogue
    @Dependency(\.photoStore) var photoStore
    @Dependency(\.locale) var locale
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<ShareFeature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        ModalBar(TegolaAction.share.label) { send(.closeTapped) }
        ScrollView {
          VStack(alignment: .leading, spacing: TegolaSpace.l) {
            if store.offersMyCopy {
              HStack(spacing: TegolaSpace.xs) {
                Pill(Text("The record", bundle: .module), isActive: store.kind == .record) {
                  send(.kindTapped(.record))
                }
                .accessibilityIdentifier("share.record")
                Pill(Text("My copy", bundle: .module), isActive: store.kind == .myCopy) {
                  send(.kindTapped(.myCopy))
                }
                .accessibilityIdentifier("share.myCopy")
              }
            }
            Group {
              switch store.kind {
              case .record: Text("The public facts, the same for every copy.", bundle: .module)
              case .myCopy: Text("Yours: its condition, its details and its photo.", bundle: .module)
              }
            }
            .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
            if store.asksForPrice { asking }
            if let card = cardView {
              card.frame(maxWidth: .infinity)
              if let image = card.rendered() {
                ShareLink(
                  item: image,
                  preview: SharePreview(Text(verbatim: store.card?.title ?? ""), image: image)
                ) {
                  TegolaAction.share.label
                }
                .buttonStyle(.tegola(.accent))
                .accessibilityIdentifier("share.send")
              }
            }
          }
          .padding(TegolaSpace.gutter)
        }
      }
      .background(theme[.surface].color)
    }

    var cardView: ShareCardView? {
      guard let card = store.card, let object = store.object else { return nil }
      let shelf = store.snapshot.shelf
      let photo: Image? =
        card.photos.first.flatMap { id in shelf.photos[id] }
        .flatMap { photoStore.load($0.fileName) }
        .flatMap(Self.image)
      return ShareCardView(
        card: card,
        manifest: catalogue.manifest(object.typeID),
        type: try? catalogue.resolve(object.typeID, subtype: object.subtype),
        photo: photo
      )
    }

    var asking: some View {
      let code = locale.currency?.identifier ?? "EUR"
      return VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        FieldLabel(Text("Asking price (optional)", bundle: .module))
        FieldBox {
          HStack {
            Text(verbatim: code).foregroundStyle(TegolaRole.textMeta)
            TextField(
              value: Binding(get: { store.asking }, set: { send(.askingChanged($0)) }),
              format: .number,
              label: { Text(verbatim: code) }
            )
            #if os(iOS)
              .keyboardType(.decimalPad)
            #endif
            .accessibilityIdentifier("share.asking")
          }
        }
      }
    }

    static func image(_ data: Data) -> Image? {
      #if canImport(UIKit)
        UIImage(data: data).map(Image.init(uiImage:))
      #else
        NSImage(data: data).map(Image.init(nsImage:))
      #endif
    }
  }
#endif

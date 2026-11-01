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

  /// The wishlist (F16): the dashed collection inside Shelf.
  @ViewAction(for: WishlistFeature.self)
  public struct WishlistView: View {
    public let store: StoreOf<WishlistFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<WishlistFeature>) {
      self.store = store
    }

    public var body: some View {
      let wishlist = store.wishlist
      ScrollView {
        VStack(alignment: .leading, spacing: TegolaSpace.l) {
          let count = wishlist.wants.count
          ScreenHeader(
            eyebrow: Text("\(count) wanted", bundle: .module),
            title: [Text("Wishlist", bundle: .module)]
          )
          if wishlist.isEmpty {
            EmptyState(
              title: [Text("Nothing wanted", bundle: .module), Text("yet", bundle: .module)],
              message: Text("Add something as wanted and it waits here, dashed, until it arrives.", bundle: .module)
            ) { EmptyView() }
          } else {
            ShareLink(
              item: WishlistCardImage(card: WishlistCard(shelf: store.snapshot.shelf), catalogue: catalogue),
              preview: SharePreview(Text("Wishlist", bundle: .module))
            ) {
              Text("Share the list", bundle: .module)
            }
            .buttonStyle(.tegola(.secondary))
            .accessibilityIdentifier("wishlist.share")
            ForEach(wishlist.wants) { want in row(want) }
          }
        }
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.top, TegolaSpace.l)
        .padding(.bottom, TegolaSpace.xxl)
      }
      .background(theme[.surface].color)
    }

    func row(_ want: Wishlist.Want) -> some View {
      let object = want.object
      let manifest = catalogue.manifest(object.typeID)
      return VStack(spacing: TegolaSpace.xs) {
        Button {
          send(.wantTapped(object.id))
        } label: {
          ObjectRow(
            title: Text(verbatim: object.title),
            meta: meta(want),
            gradient: manifest?.gradient ?? [],
            mark: manifest?.mark ?? "",
            notYours: true
          ) {
            if object.isGrail { Chip(Text("Grail", bundle: .module), fill: .accentHighlight, ink: .onAccentHighlight) }
          }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("wishlist.want.\(object.title)")
        HStack(spacing: TegolaSpace.m) {
          Button {
            send(.grailTapped(object.id))
          } label: {
            object.isGrail ? Text("Not a grail", bundle: .module) : Text("Grail", bundle: .module)
          }
          .buttonStyle(.tegola(.quiet)).fixedSize()
          .accessibilityIdentifier("wishlist.grail.\(object.title)")
          Spacer()
          Button {
            send(.arrivedTapped(object.id))
          } label: {
            Text("It arrived", bundle: .module)
          }
          .buttonStyle(.tegola(.confirm)).fixedSize()
          .accessibilityIdentifier("wishlist.arrived.\(object.title)")
        }
      }
    }

    func meta(_ want: Wishlist.Want) -> Text {
      var parts: [String] = []
      if let priority = want.object.priority {
        parts.append(String(localized: "Priority \(priority)", bundle: .module))
      }
      if let cap = want.priceCap {
        let amount = cap.amount.formatted(.currency(code: cap.currency.code))
        parts.append(String(localized: "Up to \(amount)", bundle: .module))
      }
      return Text(verbatim: parts.joined(separator: " · "))
    }
  }
#endif

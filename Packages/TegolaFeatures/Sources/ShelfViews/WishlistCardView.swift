#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaCatalogue
  import TegolaDesignSystem
  public import TegolaDesignTokens
  public import TegolaModel
  import UniformTypeIdentifiers

  /// The wishlist as a card (F14, PD-071): what's wanted, grails marked, and nothing about what's owned or what it
  /// would cost. It shows only `WishlistCard`.
  public struct WishlistCardView: View {
    let card: WishlistCard
    let catalogue: Catalogue
    @Environment(\.tegolaTheme) private var theme

    public init(card: WishlistCard, catalogue: Catalogue) {
      self.card = card
      self.catalogue = catalogue
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        Text("On my wishlist", bundle: .module)
          .tegolaTextStyle(TegolaType.displaySmall).foregroundStyle(TegolaRole.text)
        ForEach(card.wants, id: \.id) { want in
          HStack(alignment: .firstTextBaseline, spacing: TegolaSpace.s) {
            Text(verbatim: want.isGrail ? "★" : "·").foregroundStyle(TegolaRole.accentAction)
            VStack(alignment: .leading, spacing: 2) {
              Text(verbatim: want.title).tegolaTextStyle(TegolaType.label).foregroundStyle(TegolaRole.text)
              let noun = catalogue.manifest(want.typeID)?.name.noun(for: 1)
              let line = [noun, want.subtype, want.year.map(String.init)].compactMap { $0 }.joined(separator: " · ")
              if !line.isEmpty {
                Text(verbatim: line).tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta)
              }
            }
          }
        }
        Text("Shared from Tegola", bundle: .module)
          .tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMuted)
          .padding(.top, TegolaSpace.xs)
      }
      .padding(TegolaSpace.l)
      .frame(width: ShareCardView.width, alignment: .leading)
      .background(theme[.surfaceRaised].color)
      .clipShape(RoundedRectangle(cornerRadius: TegolaRadius.card))
      .overlay(
        RoundedRectangle(cornerRadius: TegolaRadius.card).strokeBorder(theme[.edge].color, lineWidth: 2.5)
      )
    }
  }

  /// The wishlist card, rendered only when the share sheet sends it.
  public struct WishlistCardImage: Transferable, Sendable {
    let card: WishlistCard
    let catalogue: Catalogue

    public init(card: WishlistCard, catalogue: Catalogue) {
      self.card = card
      self.catalogue = catalogue
    }

    public static var transferRepresentation: some TransferRepresentation {
      DataRepresentation(exportedContentType: .png) { item in
        guard let data = await item.png() else { throw CocoaError(.fileWriteUnknown) }
        return data
      }
    }

    @MainActor
    func png() -> Data? {
      let renderer = ImageRenderer(content: WishlistCardView(card: card, catalogue: catalogue).tegolaTheme(.board))
      renderer.scale = 3
      #if canImport(UIKit)
        return renderer.uiImage?.pngData()
      #else
        return renderer.nsImage?.tiffRepresentation
      #endif
    }
  }
#endif

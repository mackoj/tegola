#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaCatalogue
  import TegolaDesignSystem
  public import TegolaDesignTokens
  public import TegolaModel
  import UniformTypeIdentifiers

  /// The share card (F14, D-79) as an image people receive: the type's tint and mark, the title, the facts, and on
  /// *my copy* the hero photo and an asking price. It shows only what `ShareCard` holds, so what was paid can't reach
  /// it. Drawn at a fixed width for the renderer.
  public struct ShareCardView: View {
    let card: ShareCard
    let manifest: TypeManifest?
    let type: EffectiveType?
    let photo: Image?
    @Environment(\.tegolaTheme) private var theme

    public static let width: Double = 360

    public init(card: ShareCard, manifest: TypeManifest?, type: EffectiveType?, photo: Image? = nil) {
      self.card = card
      self.manifest = manifest
      self.type = type
      self.photo = photo
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        Group {
          if let photo {
            photo.resizable().scaledToFill()
          } else {
            TypeTint(gradient: manifest?.gradient ?? [], mark: manifest?.mark ?? "")
          }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .bottom) {
          Rectangle().fill(theme[.edge].color).frame(height: TegolaBorder.standard)
        }
        VStack(alignment: .leading, spacing: TegolaSpace.s) {
          if let noun = manifest?.name.noun(for: 1) {
            Text(verbatim: [noun, card.subtype].compactMap { $0 }.joined(separator: " · "))
              .tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta)
          }
          Text(verbatim: card.title.isEmpty ? "—" : card.title)
            .tegolaTextStyle(TegolaType.displaySmall).foregroundStyle(TegolaRole.text)
            .fixedSize(horizontal: false, vertical: true)
          ForEach(card.facts, id: \.key) { fact in
            HStack(alignment: .firstTextBaseline) {
              Text(verbatim: fact.label).tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta)
              Spacer(minLength: TegolaSpace.m)
              fact.value.text(unit: unit(fact.key)).tegolaTextStyle(TegolaType.label)
                .foregroundStyle(TegolaRole.text).multilineTextAlignment(.trailing)
            }
          }
          if let asking = card.askingPrice {
            HStack {
              Text("Asking", bundle: .module).tegolaTextStyle(TegolaType.metaSmall)
              Spacer()
              Text(asking.amount, format: .currency(code: asking.currency.code)).tegolaTextStyle(TegolaType.heading)
            }
            .foregroundStyle(TegolaRole.onAccentHighlight)
            .padding(TegolaSpace.s)
            .printed(fill: .accentHighlight, radius: TegolaRadius.badge, shadow: 0)
          }
          Text("Shared from Tegola", bundle: .module)
            .tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMuted)
            .padding(.top, TegolaSpace.xs)
        }
        .padding(TegolaSpace.l)
      }
      .frame(width: Self.width)
      .background(theme[.surfaceRaised].color)
      .clipShape(RoundedRectangle(cornerRadius: TegolaRadius.card))
      .overlay(RoundedRectangle(cornerRadius: TegolaRadius.card).strokeBorder(theme[.edge].color, lineWidth: 2.5))
    }

    func unit(_ key: FieldKey) -> String? {
      guard case .field(let name) = key else { return nil }
      return type?.field(name)?.field.unit
    }
  }

  extension ShareCardView {
    /// The card as an image for the share sheet (F14): rendered on the phone, sent as a picture, no link.
    @MainActor
    public func rendered(theme: TegolaTheme = .board, scale: Double = 3) -> Image? {
      let renderer = ImageRenderer(content: tegolaTheme(theme))
      renderer.scale = scale
      #if canImport(UIKit)
        return renderer.uiImage.map(Image.init(uiImage:))
      #else
        return renderer.nsImage.map(Image.init(nsImage:))
      #endif
    }
  }

  /// A share card the share sheet renders only when it's sent (review of M7, finding 7): a list of loans doesn't draw
  /// every card each time it redraws.
  public struct ShareCardImage: Transferable, Sendable {
    let card: ShareCard
    let manifest: TypeManifest?
    let type: EffectiveType?

    public init(card: ShareCard, manifest: TypeManifest?, type: EffectiveType?) {
      self.card = card
      self.manifest = manifest
      self.type = type
    }

    public static var transferRepresentation: some TransferRepresentation {
      DataRepresentation(exportedContentType: .png) { item in
        guard let data = await item.png() else { throw CocoaError(.fileWriteUnknown) }
        return data
      }
    }

    @MainActor
    func png() -> Data? {
      let view = ShareCardView(card: card, manifest: manifest, type: type).tegolaTheme(.board)
      let renderer = ImageRenderer(content: view)
      renderer.scale = 3
      #if canImport(UIKit)
        return renderer.uiImage?.pngData()
      #else
        return renderer.nsImage?.tiffRepresentation
      #endif
    }
  }
#endif

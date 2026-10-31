#if canImport(SwiftUI)
  public import ComposableArchitecture
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  @ViewAction(for: PlacesFeature.self)
  public struct PlacesView: View {
    public let store: StoreOf<PlacesFeature>
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<PlacesFeature>) {
      self.store = store
    }

    public var body: some View {
      let shelf = store.snapshot.shelf
      ScrollView {
        VStack(alignment: .leading, spacing: TegolaSpace.l) {
          ScreenHeader(title: [Text("Places", bundle: .module)])
          ForEach(Array(shelf.nearDuplicatePlaces().enumerated()), id: \.offset) { _, pair in
            let (kept, typo) = pair
            VStack(alignment: .leading, spacing: TegolaSpace.s) {
              Text("Same place?", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
              Text("“\(typo.name)” looks like “\(kept.name)”.", bundle: .module)
                .tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.onAccentHighlight)
              Button {
                send(.mergeTapped(typo.id, into: kept.id))
              } label: {
                Text("Merge into \(kept.name)", bundle: .module)
              }
              .buttonStyle(.tegola(.primary))
              .accessibilityIdentifier("places.merge")
            }
            .padding(TegolaSpace.l)
            .printed(fill: .accentHighlight, radius: TegolaRadius.card)
          }
          ForEach(shelf.livePlaces.filter { $0.parentID == nil }.sorted { $0.name < $1.name }) { place in
            let count = shelf.objects.values.filter { object in
              object.letGo == nil && (object.placeID.map(shelf.placeAndInside(place.id).contains) ?? false)
            }.count
            Button {
              send(.placeTapped(place.id))
            } label: {
              PlaceRow(name: place.name, count: count)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("places.place.\(place.name)")
          }
        }
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.vertical, TegolaSpace.l)
      }
      .background(theme[.surface].color)
    }
  }

  @ViewAction(for: PlaceFeature.self)
  public struct PlaceView: View {
    public let store: StoreOf<PlaceFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<PlaceFeature>) {
      self.store = store
    }

    public var body: some View {
      let shelf = store.snapshot.shelf
      ScrollView {
        VStack(alignment: .leading, spacing: TegolaSpace.l) {
          ScreenHeader(
            eyebrow: Text(verbatim: shelf.placePath(of: store.id) ?? ""),
            title: [Text(verbatim: shelf.places[store.id]?.name ?? "")]
          )
          ForEach(store.children) { child in
            Button {
              send(.placeTapped(child.id))
            } label: {
              PlaceRow(name: child.name, count: nil)
            }
            .buttonStyle(.plain)
          }
          ForEach(store.objects) { object in
            let manifest = catalogue.manifest(object.typeID)
            Button {
              send(.objectTapped(object.id))
            } label: {
              ObjectRow(
                title: Text(verbatim: object.title),
                meta: Text(verbatim: object.placeID.flatMap { shelf.placePath(of: $0) } ?? ""),
                gradient: manifest?.gradient ?? [],
                mark: manifest?.mark ?? "",
                notYours: object.ownership != .owned
              )
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.vertical, TegolaSpace.l)
      }
      .background(theme[.surface].color)
    }
  }

  struct PlaceRow: View {
    let name: String
    let count: Int?

    var body: some View {
      HStack {
        Text(verbatim: name).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
        Spacer()
        if let count {
          Text(count, format: .number).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        }
        Image(systemName: "chevron.right").foregroundStyle(TegolaRole.textMeta).accessibilityHidden(true)
      }
      .padding(TegolaSpace.m)
      .frame(minHeight: TegolaMetrics.minimumHitTarget)
      .printed(radius: TegolaRadius.card)
    }
  }
#endif

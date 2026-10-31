#if canImport(SwiftUI)
  public import ComposableArchitecture
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  @ViewAction(for: FindFeature.self)
  public struct FindView: View {
    public let store: StoreOf<FindFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<FindFeature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: TegolaSpace.l) {
          ScreenHeader(title: [Text("Find", bundle: .module)])
          FieldBox {
            HStack {
              Image(systemName: "magnifyingglass").foregroundStyle(TegolaRole.textMeta).accessibilityHidden(true)
              TextField(
                text: Binding(get: { store.query.text }, set: { send(.textChanged($0)) }),
                prompt: Text("Title, artist, track, place…", bundle: .module),
                label: { Text("Find", bundle: .module) }
              )
              .accessibilityIdentifier("find.field")
            }
          }
          chips
          if store.query.isEmpty {
            savedViews
          } else {
            results
          }
        }
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.top, TegolaSpace.l)
        .padding(.bottom, TegolaSpace.xxl)
      }
      .background(theme[.surface].color)
    }

    // Filters stack as chips: the four types, lent out, the archive.
    var chips: some View {
      FlowLayout(spacing: TegolaSpace.xs) {
        ForEach(catalogue.enabled) { manifest in
          Pill(
            Text(verbatim: manifest.name.hobby ?? manifest.name.plural),
            isActive: store.query.types.contains(manifest.id)
          ) { send(.typeTapped(manifest.id)) }
        }
        Pill(Text("Lent out", bundle: .module), isActive: store.query.lentOut) { send(.lentOutTapped) }
        Pill(Text("Archive too", bundle: .module), isActive: store.query.includeArchive) { send(.archiveTapped) }
      }
    }

    var savedViews: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.s) {
        Text("Saved views", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
        ForEach(SavedView.allCases, id: \.self) { view in
          let count = search(SearchQuery(view: view), in: store.snapshot.shelf, catalogue: catalogue).count
          Button {
            send(.viewTapped(view))
          } label: {
            HStack {
              view.title.tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
              Spacer()
              Text(count, format: .number).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
            }
            .padding(TegolaSpace.m)
            .frame(minHeight: TegolaMetrics.minimumHitTarget)
            .printed(radius: TegolaRadius.card)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("find.view.\(view.rawValue)")
        }
      }
    }

    @ViewBuilder
    var results: some View {
      let hits = search(store.query, in: store.snapshot.shelf, catalogue: catalogue)
      HStack {
        if let view = store.query.view {
          Chip(view.title, fill: .accentHighlight, ink: .onAccentHighlight)
        }
        Text("\(hits.count) found", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(
          TegolaRole.textMeta
        )
        Spacer()
        Button {
          send(.clearTapped)
        } label: {
          Text("Clear", bundle: .module)
        }
        .buttonStyle(.tegola(.quiet)).fixedSize()
      }
      if hits.isEmpty {
        Text("Nothing matches. Try fewer words, or include the archive.", bundle: .module)
          .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
      }
      ForEach(hits) { hit in
        if let object = store.snapshot.shelf.objects[hit.object] {
          row(object, hit: hit)
        }
      }
    }

    func row(_ object: ShelfObject, hit: SearchHit) -> some View {
      let manifest = catalogue.manifest(object.typeID)
      let matched = ListFormatter.localizedString(byJoining: hit.matched)
      let meta: Text =
        object.letGo != nil
        ? Text("Let go", bundle: .module)
        : hit.matched.isEmpty
          ? Text(verbatim: manifest?.name.singular ?? "")
          : Text("Matched \(matched)", bundle: .module)
      return Button {
        send(.resultTapped(object.id))
      } label: {
        ObjectRow(
          title: Text(verbatim: object.title.isEmpty ? "—" : object.title),
          meta: meta,
          gradient: manifest?.gradient ?? [],
          mark: manifest?.mark ?? "",
          notYours: object.ownership != .owned || object.letGo != nil
        )
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("find.result.\(object.title)")
    }
  }

  extension SavedView {
    var title: Text {
      switch self {
      case .imperfect: Text("Imperfect", bundle: .module)
      case .duplicates: Text("Duplicates", bundle: .module)
      case .signed: Text("Signed", bundle: .module)
      case .mightLetGo: Text("Might let go", bundle: .module)
      }
    }
  }
#endif

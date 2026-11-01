#if canImport(SwiftUI)
  public import ComposableArchitecture
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import ShelfViews
  import TegolaModel
  import TegolaStorage

  @ViewAction(for: CollectionFeature.self)
  public struct CollectionView: View {
    @Bindable public var store: StoreOf<CollectionFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<CollectionFeature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: TegolaSpace.l) {
          if let collection = store.collection {
            header(collection)
            sortPills
            if !store.placeChoices.isEmpty { placePills }
            if !store.statusChoices.isEmpty { statusPills }
            rows
          }
        }
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.top, TegolaSpace.s)
        .padding(.bottom, TegolaSpace.xxl)
      }
      .background(theme[.surface].color)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            send(.renameTapped)
          } label: {
            Text("Rename", bundle: .module)
          }
          .accessibilityIdentifier("collection.rename")
        }
      }
      .sheet(isPresented: Binding(get: { store.renameDraft != nil }, set: { if !$0 { send(.renameCancelTapped) } })) {
        renameSheet
      }
    }

    func header(_ collection: ShelfCollection) -> some View {
      let meta = CollectionMeta(collection: collection, shelf: store.snapshot.shelf, catalogue: catalogue)
      let noun = meta.noun?.uppercased() ?? String(localized: "objects", bundle: .module).uppercased()
      return ScreenHeader(
        eyebrow: meta.lent > 0
          ? Text("\(meta.count) \(noun) · \(meta.lent) lent", bundle: .module)
          : Text(verbatim: "\(meta.count.formatted()) \(noun)"),
        title: [Text(verbatim: collection.name)]
      )
    }

    var sortPills: some View {
      HStack(spacing: TegolaSpace.s) {
        ForEach(CollectionFeature.Sort.allCases, id: \.self) { sort in
          Pill(sort.label, isActive: store.sort == sort) { send(.sortTapped(sort)) }
        }
      }
    }

    var placePills: some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: TegolaSpace.s) {
          Pill(Text("Everywhere", bundle: .module), isActive: store.place == nil) { send(.placeTapped(nil)) }
          ForEach(store.placeChoices) { place in
            Pill(Text(verbatim: place.name), isActive: store.place == place.id) { send(.placeTapped(place.id)) }
          }
        }
        .padding(.trailing, TegolaShadow.small)
      }
    }

    var statusPills: some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: TegolaSpace.s) {
          Pill(Text("Any status", bundle: .module), isActive: store.status == nil) { send(.statusTapped(nil)) }
          ForEach(store.statusChoices, id: \.self) { status in
            Pill(status.label, isActive: store.status == status) { send(.statusTapped(status)) }
              .accessibilityIdentifier("collection.status.\(status.rawValue)")
          }
        }
        .padding(.trailing, TegolaShadow.small)
      }
    }

    @ViewBuilder
    var rows: some View {
      let objects = store.objects
      if store.collection?.typeID == nil {
        // A mixed collection groups by type, in the catalogue's order.
        let groups = Dictionary(grouping: objects, by: \.typeID)
        ForEach(groups.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { type in
          Text(verbatim: catalogue.manifest(type)?.name.plural ?? type.rawValue)
            .tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
          ForEach(groups[type] ?? []) { row($0) }
        }
      } else {
        ForEach(objects) { row($0) }
      }
    }

    func row(_ object: ShelfObject) -> some View {
      let manifest = catalogue.manifest(object.typeID)
      let subtype = object.subtype.flatMap { key in manifest?.subtypes.first { $0.key == key }?.label }
      var meta: [String] = []
      if case .text(let subtitle) = object.values[.subtitle] { meta.append(subtitle) }
      if let subtype { meta.append(subtype) }
      if case .year(let year) = object.values[.year] { meta.append(String(year)) }
      let notYours = object.ownership != .owned
      let lent = store.snapshot.shelf.openLoan(on: object.id)?.direction == .out
      return Button {
        send(.objectTapped(object.id))
      } label: {
        ObjectRow(
          title: Text(verbatim: object.title.isEmpty ? "—" : object.title),
          meta: Text(verbatim: meta.joined(separator: " · ")),
          gradient: manifest?.gradient ?? [],
          mark: manifest?.mark ?? "",
          notYours: notYours
        ) {
          if object.isGrail {
            Chip(Text("Grail", bundle: .module), fill: .accentGrail, ink: .onAccentGrail)
          } else if lent {
            StatusChip(.watch, label: Text("Lent", bundle: .module))
          } else if object.bulk == .quantity {
            Chip(Text(verbatim: "×\(object.quantity)"))
          } else if object.ownership == .wanted {
            Chip(Text("Wanted", bundle: .module))
          } else if object.ownership == .borrowed {
            Chip(Text("Borrowed", bundle: .module))
          }
        }
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("collection.object.\(object.title)")
    }

    var renameSheet: some View {
      VStack(spacing: 0) {
        ModalBar(
          Text("Rename", bundle: .module),
          dismiss: { send(.renameCancelTapped) },
          canSave: !(store.renameDraft ?? "").trimmingCharacters(in: .whitespaces).isEmpty,
          save: { send(.renameSaveTapped) }
        )
        TextField(
          text: Binding(get: { store.renameDraft ?? "" }, set: { send(.renameChanged($0)) }),
          label: { Text("Name", bundle: .module) }
        )
        .tegolaTextStyle(TegolaType.label)
        .padding(TegolaSpace.m)
        .printed(radius: TegolaRadius.input)
        .padding(TegolaSpace.gutter)
        .accessibilityIdentifier("collection.renameField")
        Spacer()
      }
      .background(theme[.surface].color)
      .presentationDetents([.height(220)])
    }
  }

  extension CollectionFeature.Sort {
    var label: Text {
      switch self {
      case .recent: Text("Recent", bundle: .module)
      case .title: Text("A–Z", bundle: .module)
      case .year: Text("Year", bundle: .module)
      }
    }
  }
#endif

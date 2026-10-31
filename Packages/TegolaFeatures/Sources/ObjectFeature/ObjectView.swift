#if canImport(SwiftUI)
  public import ComposableArchitecture
  import ObjectEditFeature
  import ShelfViews
  import PhotosUI
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  @ViewAction(for: ObjectFeature.self)
  public struct ObjectView: View {
    @Bindable public var store: StoreOf<ObjectFeature>
    @Dependency(\.catalogue) var catalogue
    @Dependency(\.photoStore) var photoStore
    @State private var pickedPhoto: PhotosPickerItem?
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<ObjectFeature>) {
      self.store = store
    }

    /// The paper panel rises over the hero's foot (board 04: `margin-top: -14px`).
    static let panelOverlap: Double = 14

    public var body: some View {
      ScrollView {
        if let object = store.object, let manifest = catalogue.manifest(object.typeID),
          let type = try? catalogue.resolve(object.typeID, subtype: object.subtype)
        {
          let slots = ObjectSlots(
            object: object,
            type: type,
            manifest: manifest,
            shelf: store.snapshot.shelf.shelf,
            money: store.snapshot.shelf.money
          )
          VStack(spacing: 0) {
            hero(manifest, photo: store.snapshot.shelf.shelf.photos(of: object.id).first)
            VStack(alignment: .leading, spacing: TegolaSpace.l) {
              spine(object, manifest: manifest, slots: slots)
              status(object)
              signature(slots, type: type)
              fields(slots)
              actions(object)
              history(type)
            }
            .padding(.horizontal, TegolaSpace.gutter)
            .padding(.top, TegolaSpace.xl)
            .padding(.bottom, TegolaSpace.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme[.surface].color)
            .clipShape(
              UnevenRoundedRectangle(
                topLeadingRadius: TegolaRadius.emptyFrame,
                topTrailingRadius: TegolaRadius.emptyFrame
              )
            )
            .overlay(alignment: .top) {
              UnevenRoundedRectangle(
                topLeadingRadius: TegolaRadius.emptyFrame,
                topTrailingRadius: TegolaRadius.emptyFrame
              )
              .stroke(theme[.edge].color, lineWidth: TegolaBorder.standard)
              .frame(height: TegolaRadius.emptyFrame)
              .mask(alignment: .top) { Rectangle().frame(height: TegolaRadius.emptyFrame / 2) }
            }
            .padding(.top, -Self.panelOverlap)
          }
        }
      }
      .background(theme[.surfaceStage].color)
      .sheet(item: $store.scope(state: \.edit, action: \.edit)) { edit in
        ObjectEditView(store: edit)
      }
      .photosPicker(
        isPresented: Binding(get: { store.isPickingPhoto }, set: { if !$0 { send(.photoPickerDismissed) } }),
        selection: $pickedPhoto,
        matching: .images
      )
      .onChange(of: pickedPhoto) { _, item in
        guard let item else { return }
        Task {
          if let data = try? await item.loadTransferable(type: Data.self) { send(.photoPicked(data)) }
          pickedPhoto = nil
        }
      }
    }

    // 1. Hero: the collector's photo, or the type's flat hero (PD-145).
    @ViewBuilder
    func hero(_ manifest: TypeManifest, photo: Photo?) -> some View {
      if let photo, let image = photoStore.load(photo.fileName).flatMap(Self.image) {
        image
          .resizable()
          .scaledToFill()
          .frame(height: 320)
          .frame(maxWidth: .infinity)
          .clipped()
          .accessibilityLabel(Text("Photo", bundle: .module))
      } else {
        TypeTint(gradient: manifest.gradient, mark: manifest.mark, bottomInset: Self.panelOverlap)
          .frame(height: 260)
          .accessibilityHidden(true)
      }
    }

    static func image(_ data: Data) -> Image? {
      #if canImport(UIKit)
        UIImage(data: data).map(Image.init(uiImage:))
      #else
        NSImage(data: data).map(Image.init(nsImage:))
      #endif
    }

    // 2. Spine: chips, the title, the subtitle, then the type's labelled spine lines.
    @ViewBuilder
    func spine(_ object: ShelfObject, manifest: TypeManifest, slots: ObjectSlots) -> some View {
      HStack(spacing: TegolaSpace.xs) {
        if let subtype = object.subtype.flatMap({ key in manifest.subtypes.first { $0.key == key } }) {
          Chip(Text(verbatim: subtype.label), fill: .accentHighlight, ink: .onAccentHighlight, tilt: -2)
        }
        if case .year(let year) = object.values[.year] { Chip(Text(verbatim: String(year))) }
        if object.isGrail { Chip(Text("Grail", bundle: .module), fill: .accentGrail, ink: .onAccentGrail, tilt: 2) }
      }
      VStack(alignment: .leading, spacing: TegolaSpace.xxs) {
        Text(verbatim: object.title.isEmpty ? "—" : object.title)
          .tegolaTextStyle(TegolaType.displaySmall)
          .foregroundStyle(TegolaRole.text)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("object.title")
        if case .text(let subtitle) = object.values[.subtitle] {
          Text(verbatim: subtitle).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.textMuted)
        }
      }
      ForEach(slots.spine.filter { $0.key != .subtitle && $0.key != .year }, id: \.key) { line in
        factRow(Text(verbatim: line.label), line.value.text())
      }
    }

    // 3. Status: one chip. Clocks and their statuses arrive in M4; until then, only what needs the collector shows.
    @ViewBuilder
    func status(_ object: ShelfObject) -> some View {
      let shelf = store.snapshot.shelf.shelf
      if let loan = shelf.openLoan(on: object.id), loan.direction == .out, object.letGo == nil {
        let name = shelf.persons[loan.personID]?.name ?? ""
        StatusChip(.watch, label: Text("Lent to \(name)", bundle: .module))
      } else {
        identityStatus(object)
      }
    }

    @ViewBuilder
    func identityStatus(_ object: ShelfObject) -> some View {
      switch (object.identity, object.ownership, object.letGo) {
      case (_, _, .some): StatusChip(.gone, label: Text("Let go", bundle: .module))
      case (.needsDetails, _, _): StatusChip(.watch, label: Text("Needs details", bundle: .module))
      case (.unconfirmed, _, _): StatusChip(.watch, label: Text("Unconfirmed", bundle: .module))
      case (_, .wanted, _): StatusChip(.fine, label: Text("Wanted", bundle: .module))
      case (_, .borrowed, _): StatusChip(.fine, label: Text("Borrowed", bundle: .module))
      default: EmptyView()
      }
    }

    // 4. Signature: the ladder and the set, as the type binds them.
    @ViewBuilder
    func signature(_ slots: ObjectSlots, type: EffectiveType) -> some View {
      if !slots.ladder.isEmpty {
        LadderSignature(
          rungs: slots.ladder.map { rung in
            LadderSignature.Rung(label: rung.label, step: rung.grade.flatMap { type.conditions.firstIndex(of: $0) })
          },
          steps: type.conditions.count
        )
      }
      if let set = slots.set, !set.slots.isEmpty {
        SetSignature(slots: set.slots, present: set.present)
      }
    }

    // 5. Fields: every field with a value, its label from the type, AUTO until the collector touches it.
    @ViewBuilder
    func fields(_ slots: ObjectSlots) -> some View {
      if !slots.fields.isEmpty {
        VStack(spacing: 0) {
          ForEach(slots.fields, id: \.field.key) { line in
            factRow(Text(verbatim: line.field.label), line.value.text(unit: line.field.unit), auto: line.isAuto)
          }
        }
      }
    }

    func factRow(_ label: Text, _ value: Text, auto: Bool = false) -> some View {
      HStack(alignment: .firstTextBaseline) {
        label.tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta)
        if auto { Chip(Text("Auto", bundle: .module), fill: .accentHighlight, ink: .onAccentHighlight) }
        Spacer(minLength: TegolaSpace.m)
        value.tegolaTextStyle(TegolaType.label).foregroundStyle(TegolaRole.text).multilineTextAlignment(.trailing)
      }
      .padding(.vertical, TegolaSpace.s)
      .overlay(alignment: .bottom) { Rectangle().fill(theme[.hairline].color).frame(height: 1.5) }
      .accessibilityElement(children: .combine)
    }

    // 6. Actions: the app's verbs. Edit and Photo always; Might let go on what's owned and kept.
    func actions(_ object: ShelfObject) -> some View {
      VStack(spacing: TegolaSpace.m) {
        ButtonPair {
          Button {
            send(.editTapped)
          } label: {
            Text("Edit", bundle: .module)
          }
          .buttonStyle(.tegola(.primary))
          .accessibilityIdentifier("object.edit")
        } trailing: {
          Button {
            send(.photoTapped)
          } label: {
            Text("Photo", bundle: .module)
          }
          .buttonStyle(.tegola(.secondary))
          .accessibilityIdentifier("object.photo")
        }
        if object.counts {
          Button {
            send(.mightLetGoTapped)
          } label: {
            object.mightLetGo ? Text("Keeping it after all", bundle: .module) : Text("Might let go", bundle: .module)
          }
          .buttonStyle(.tegola(.quiet))
          .accessibilityIdentifier("object.mightLetGo")
        }
      }
    }

    // 7. History: append-only, newest first.
    @ViewBuilder
    func history(_ type: EffectiveType) -> some View {
      let shelf = store.snapshot.shelf.shelf
      Text("History", bundle: .module).tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
      Timeline(
        store.history.map { event in
          Timeline.Entry(
            id: event.id.description,
            date: Text(event.at, format: .dateTime.day().month(.abbreviated).year()),
            line: event.historyLine(shelf: shelf, type: type)
          )
        }
      )
    }
  }
#endif

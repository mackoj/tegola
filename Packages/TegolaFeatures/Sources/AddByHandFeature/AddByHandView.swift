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

  @ViewAction(for: AddByHandFeature.self)
  public struct AddByHandView: View {
    public let store: StoreOf<AddByHandFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<AddByHandFeature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        ModalBar(
          Text("Type it", bundle: .module),
          dismissLabel: Text("Close", bundle: .module),
          dismiss: { send(.closeTapped) }
        )
        ScrollView {
          VStack(alignment: .leading, spacing: TegolaSpace.l) {
            if let type = store.type, let manifest = catalogue.manifest(type) {
              form(manifest)
            } else {
              typePicker
            }
          }
          .padding(TegolaSpace.gutter)
        }
      }
      .background(theme[.surface].color)
    }

    // Step 1: what is it? The four v1 types, each in its own tint (D-23).
    var typePicker: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.m) {
        DisplayTitle([Text("What are you", bundle: .module), Text("adding?", bundle: .module)])
        ForEach(catalogue.enabled) { manifest in
          Button {
            send(.typeTapped(manifest.id))
          } label: {
            ObjectRow(
              title: Text(verbatim: manifest.name.hobby ?? manifest.name.plural),
              meta: Text(verbatim: manifest.name.singular),
              gradient: manifest.gradient,
              mark: manifest.mark
            )
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("add.type.\(manifest.id.rawValue)")
        }
      }
    }

    // Step 2: the subtype (optional), where it goes, and the form.
    @ViewBuilder
    func form(_ manifest: TypeManifest) -> some View {
      HStack {
        Text(verbatim: manifest.name.singular).tegolaTextStyle(TegolaType.displaySmall).foregroundStyle(TegolaRole.text)
        Spacer()
        Button {
          send(.changeTypeTapped)
        } label: {
          Text("Change", bundle: .module)
        }
        .buttonStyle(.tegola(.quiet)).fixedSize()
      }
      if store.added > 0 {
        Text("\(store.added) added", bundle: .module)
          .tegolaTextStyle(TegolaType.meta).foregroundStyle(TegolaRole.textMeta)
          .accessibilityIdentifier("add.count")
      }
      if !manifest.subtypes.isEmpty {
        VStack(alignment: .leading, spacing: TegolaSpace.xs) {
          FieldLabel(Text(verbatim: manifest.spine.subtitle ?? String(localized: "Kind", bundle: .module)))
          ChoiceChips(
            options: manifest.subtypes.map(\.label),
            selected: Set(manifest.subtypes.filter { $0.key == store.subtype }.map(\.label))
          ) { label in
            let key = manifest.subtypes.first { $0.label == label }?.key
            send(.subtypeTapped(key == store.subtype ? nil : key))
          }
        }
      }
      addTo(manifest)
      if let refusal = store.refusal {
        refusal.message
          .tegolaTextStyle(TegolaType.label)
          .foregroundStyle(TegolaRole.onAccentLoss)
          .padding(TegolaSpace.m)
          .frame(maxWidth: .infinity, alignment: .leading)
          .printed(fill: .accentLoss, radius: TegolaRadius.input)
      }
      if let type = try? catalogue.resolve(manifest.id, subtype: store.subtype) {
        ValuesForm(
          manifest: manifest,
          type: type,
          money: store.snapshot.money,
          draft: store.draft,
          place: store.place,
          revealed: store.revealed,
          change: { send(.valueChanged($0, $1)) },
          changePlace: { send(.placeChanged($0)) },
          reveal: { send(.addTapped($0)) }
        )
      }
      ButtonPair {
        Button {
          send(.saveTapped(addAnother: true))
        } label: {
          Text("Save, add another", bundle: .module)
        }
        .buttonStyle(.tegola(.secondary))
        .disabled(!store.canSave)
        .accessibilityIdentifier("add.saveAnother")
      } trailing: {
        Button {
          send(.saveTapped(addAnother: false))
        } label: {
          Text("Save", bundle: .module)
        }
        .buttonStyle(.tegola(.confirm))
        .disabled(!store.canSave)
        .accessibilityIdentifier("add.save")
      }
    }

    // Add to: the collections that take this type, and the type's new one if it has none (F6).
    func addTo(_ manifest: TypeManifest) -> some View {
      let collections = store.snapshot.shelf.collections.values
        .filter { $0.typeID == nil || $0.typeID == manifest.id }
        .sorted { $0.sortKey < $1.sortKey }
      return VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        FieldLabel(Text("Add to", bundle: .module))
        FlowLayout(spacing: TegolaSpace.xs) {
          ForEach(collections) { collection in
            Pill(Text(verbatim: collection.name), isActive: store.collection == .existing(collection.id)) {
              send(.collectionTapped(.existing(collection.id)))
            }
          }
          if collections.allSatisfy({ $0.typeID != manifest.id }) {
            let new = CollectionChoice.new(name: manifest.name.collection)
            Pill(Text(verbatim: manifest.name.collection), isActive: store.collection == new) {
              send(.collectionTapped(new))
            }
          }
        }
      }
    }
  }

  extension ShelfRuleViolation {
    var message: Text {
      switch self {
      case .emptyTitle: Text("Every object needs a title.", bundle: .module)
      case .invalidValue, .unknownField, .hiddenField:
        Text("One of these values doesn't fit its field.", bundle: .module)
      default: Text("That can't be saved.", bundle: .module)
      }
    }
  }
#endif

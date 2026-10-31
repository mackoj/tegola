#if canImport(SwiftUI)
  public import ComposableArchitecture
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import ShelfViews
  import TegolaModel

  @ViewAction(for: ObjectEditFeature.self)
  public struct ObjectEditView: View {
    public let store: StoreOf<ObjectEditFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<ObjectEditFeature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        ModalBar(
          Text("Edit", bundle: .module),
          dismissLabel: Text("Cancel", bundle: .module),
          dismiss: { send(.cancelTapped) },
          saveLabel: Text("Save", bundle: .module),
          canSave: store.canSave,
          save: { send(.saveTapped) }
        )
        ScrollView {
          if let manifest = catalogue.manifest(store.typeID),
            let type = try? catalogue.resolve(store.typeID, subtype: store.subtype)
          {
            VStack(alignment: .leading, spacing: TegolaSpace.l) {
              if let refusal = store.refusal {
                refusal.message
                  .tegolaTextStyle(TegolaType.label)
                  .foregroundStyle(TegolaRole.onAccentLoss)
                  .padding(TegolaSpace.m)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .printed(fill: .accentLoss, radius: TegolaRadius.input)
              }
              ValuesForm(
                manifest: manifest,
                type: type,
                money: store.money,
                draft: store.draft,
                original: store.original,
                auto: store.auto,
                place: store.place,
                revealed: store.revealed,
                change: { send(.valueChanged($0, $1)) },
                changePlace: { send(.placeChanged($0)) },
                reveal: { send(.addTapped($0)) }
              )
            }
            .padding(TegolaSpace.gutter)
          }
        }
      }
      .background(theme[.surface].color)
    }
  }

  extension ShelfRuleViolation {
    /// What the form says when the rules refuse a save.
    var message: Text {
      switch self {
      case .emptyTitle: Text("Every object needs a title.", bundle: .module)
      case .wantedHasNoCondition: Text("A wanted object has no condition yet.", bundle: .module)
      case .invalidValue, .unknownField, .hiddenField:
        Text("One of these values doesn't fit its field.", bundle: .module)
      default: Text("That can't be saved.", bundle: .module)
      }
    }
  }
#endif

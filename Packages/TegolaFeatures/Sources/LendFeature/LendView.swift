#if canImport(SwiftUI)
  public import ComposableArchitecture
  public import SwiftUI
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel

  /// Board 18: to whom, back by when, an optional note, **Hand it over**.
  @ViewAction(for: LendFeature.self)
  public struct LendView: View {
    @Bindable public var store: StoreOf<LendFeature>
    @Dependency(\.date.now) var now
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<LendFeature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        ModalBar(heading, leaving: .cancel) { send(.cancelTapped) }
        ScrollView {
          VStack(alignment: .leading, spacing: TegolaSpace.l) {
            Text(verbatim: store.title)
              .tegolaTextStyle(TegolaType.heading)
              .foregroundStyle(TegolaRole.text)
            people
            if store.mode == .lend {
              due
              note
            }
            if store.refusal != nil {
              Text("That can't be saved.", bundle: .module)
                .tegolaTextStyle(TegolaType.label)
                .foregroundStyle(TegolaRole.accentLoss)
            }
            submit
          }
          .padding(TegolaSpace.gutter)
        }
      }
      .background(theme[.surface].color)
    }

    var heading: Text {
      switch store.mode {
      case .lend: TegolaAction.lend.label
      case .borrow: TegolaAction.markBorrowed.label
      }
    }

    @ViewBuilder
    var people: some View {
      FieldLabel(store.mode == .lend ? Text("To whom", bundle: .module) : Text("Borrowed from", bundle: .module))
      FlowLayout(spacing: TegolaSpace.xs) {
        ForEach(store.people) { person in
          Pill(Text(verbatim: person.name), isActive: store.person == person.id) {
            send(.personTapped(person.id))
          }
          .accessibilityIdentifier("lend.person.\(person.name)")
        }
        if !store.isNew {
          Pill(Text("+ New", bundle: .module), isActive: false) { send(.newTapped) }
            .accessibilityIdentifier("lend.new")
        }
      }
      if store.isNew {
        FieldBox {
          TextField(
            text: Binding(get: { store.newName }, set: { send(.newNameChanged($0)) }),
            label: { Text("Their name", bundle: .module) }
          )
          #if os(iOS)
            .textInputAutocapitalization(.words)
          #endif
          .accessibilityIdentifier("lend.name")
        }
      }
    }

    @ViewBuilder
    var due: some View {
      FieldLabel(Text("Back by", bundle: .module))
      FlowLayout(spacing: TegolaSpace.xs) {
        ForEach(LendFeature.State.Due.allCases, id: \.self) { due in
          Pill(due.label, isActive: store.due == due) { send(.dueTapped(due)) }
            .accessibilityIdentifier("lend.due.\(due)")
        }
      }
      if store.due == .date {
        // A loan is due back today or later, never in the past.
        DatePicker(
          selection: Binding(get: { store.date }, set: { send(.dateChanged($0)) }),
          in: now...,
          displayedComponents: .date,
          label: { Text("Back by", bundle: .module) }
        )
        .labelsHidden()
      }
    }

    @ViewBuilder
    var note: some View {
      FieldLabel(Text("A note (optional)", bundle: .module))
      FieldBox {
        TextField(
          text: Binding(get: { store.note }, set: { send(.noteChanged($0)) }),
          axis: .vertical,
          label: { Text("Why they wanted it, what to watch for", bundle: .module) }
        )
        .lineLimit(2...4)
        .padding(.vertical, TegolaSpace.s)
        .accessibilityIdentifier("lend.note")
      }
    }

    @ViewBuilder
    var submit: some View {
      switch store.mode {
      case .lend:
        Button {
          send(.submitTapped)
        } label: {
          Text("Hand it over", bundle: .module)
        }
        .buttonStyle(.tegola(.accent))
        .disabled(!store.canSubmit)
        .accessibilityIdentifier("lend.handOver")
      case .borrow:
        ActionButton(.save, id: "lend.handOver") { send(.submitTapped) }
          .disabled(!store.canSubmit)
      }
    }
  }

  extension LendFeature.State.Due {
    var label: Text {
      switch self {
      case .twoWeeks: Text("2 weeks", bundle: .module)
      case .oneMonth: Text("1 month", bundle: .module)
      case .date: Text("Pick a date", bundle: .module)
      case .none: Text("No date", bundle: .module)
      }
    }
  }
#endif

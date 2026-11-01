#if canImport(SwiftUI)
  public import ComposableArchitecture
  import ShelfViews
  public import SwiftUI
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel

  /// Board 20: the object and how long it was out, how it came back, a note, what gets written, **It's home**.
  @ViewAction(for: ReturnFeature.self)
  public struct ReturnView: View {
    @Bindable public var store: StoreOf<ReturnFeature>
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<ReturnFeature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        ModalBar(Text("Closing a loan", bundle: .module), leaving: .cancel) { send(.cancelTapped) }
        ScrollView {
          VStack(alignment: .leading, spacing: TegolaSpace.l) {
            let person = store.nudge.person
            Text("Back from \(person)", bundle: .module)
              .tegolaTextStyle(TegolaType.displayTitle)
              .foregroundStyle(TegolaRole.text)
            card
            FieldLabel(Text("How did it come back?", bundle: .module))
            VStack(spacing: TegolaSpace.xs) {
              ForEach(Loan.CameBack.allCases, id: \.self) { answer in
                Pill(answer.label, isActive: store.cameBack == answer) { send(.cameBackTapped(answer)) }
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .accessibilityIdentifier("return.cameBack.\(answer.rawValue)")
              }
            }
            FieldLabel(Text("For the record (optional)", bundle: .module))
            FieldBox {
              TextField(
                text: Binding(get: { store.note }, set: { send(.noteChanged($0)) }),
                axis: .vertical,
                label: { Text("How it went", bundle: .module) }
              )
              .lineLimit(2...4)
              .padding(.vertical, TegolaSpace.s)
              .accessibilityIdentifier("return.note")
            }
            written
            Button {
              send(.itsHomeTapped)
            } label: {
              Text("It's home", bundle: .module)
            }
            .buttonStyle(.tegola(.primary))
            .accessibilityIdentifier("return.itsHome")
          }
          .padding(TegolaSpace.gutter)
        }
      }
      .background(theme[.surface].color)
    }

    /// The object, and how long it was out: rust when it's late (board 20).
    var card: some View {
      let days = store.nudge.daysOut
      return VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        Text(verbatim: store.nudge.title).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
        HStack(spacing: TegolaSpace.xs) {
          Text("Out \(days) days", bundle: .module)
          if let late = store.nudge.daysOverdue {
            Text(verbatim: "·")
            Text("\(late) days overdue", bundle: .module)
          }
        }
        .tegolaTextStyle(TegolaType.meta)
        .foregroundStyle(store.nudge.daysOverdue == nil ? TegolaRole.textMeta : TegolaRole.accentLoss)
      }
      .padding(TegolaSpace.m)
      .frame(maxWidth: .infinity, alignment: .leading)
      .printed(radius: TegolaRadius.card)
    }

    /// What the history will say, before it says it.
    var written: some View {
      VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        Text("What gets written", bundle: .module).tegolaTextStyle(TegolaType.meta)
        Text(
          verbatim: ShelfEvent.returnLine(from: store.nudge.person, cameBack: store.cameBack, words: store.words)
        )
        .tegolaTextStyle(TegolaType.label)
      }
      .foregroundStyle(TegolaRole.onAccentConfirm)
      .padding(TegolaSpace.m)
      .frame(maxWidth: .infinity, alignment: .leading)
      .printed(fill: .accentConfirm, radius: TegolaRadius.card)
    }
  }

  extension Loan.CameBack {
    var label: Text {
      switch self {
      case .sameShape: Text("Came back in the same shape", bundle: .module)
      case .damaged: Text("Sleeve or box damaged", bundle: .module)
      case .somethingMissing: Text("Something missing", bundle: .module)
      }
    }
  }
#endif

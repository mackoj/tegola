#if canImport(SwiftUI)
  public import ComposableArchitecture
  import LendFeature
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  /// Board 19: the person, two tiles, everything they've had, **Lend them something**.
  @ViewAction(for: PersonFeature.self)
  public struct PersonView: View {
    @Bindable public var store: StoreOf<PersonFeature>
    @Dependency(\.catalogue) var catalogue
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<PersonFeature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        if let record = store.record {
          VStack(alignment: .leading, spacing: TegolaSpace.l) {
            ScreenHeader(eyebrow: eyebrow(record), title: [Text(verbatim: record.person.name)])
            tiles(record)
            if !record.loans.isEmpty {
              FieldLabel(Text("Everything they've had", bundle: .module))
              ForEach(record.loans) { loan in row(loan) }
            }
            Button {
              send(.lendSomethingTapped)
            } label: {
              Text("Lend them something", bundle: .module)
            }
            .buttonStyle(.tegola(.accent))
            .accessibilityIdentifier("person.lend")
          }
          .padding(.horizontal, TegolaSpace.gutter)
          .padding(.top, TegolaSpace.l)
          .padding(.bottom, TegolaSpace.xxl)
        }
      }
      .background(theme[.surface].color)
      .sheet(isPresented: Binding(get: { store.isPicking }, set: { if !$0 { send(.pickerDismissed) } })) {
        if let lend = store.scope(state: \.lend, action: \.lend.presented) {
          LendView(store: lend)
        } else {
          picker
        }
      }
    }

    func eyebrow(_ record: PersonRecord) -> Text {
      let loans = record.loans.count
      let out = record.holdsNow.count
      let count = Text("\(loans) loans", bundle: .module)
      let holding = Text("\(out) out now", bundle: .module)
      return Text("\(count) · \(holding)", bundle: .module)
    }

    @ViewBuilder
    func tiles(_ record: PersonRecord) -> some View {
      if record.lent > 0 {
        HStack(spacing: TegolaSpace.m) {
          let returned = record.returned
          let lent = record.lent
          StatTile(
            eyebrow: Text("Came back", bundle: .module),
            figure: Text("\(returned) of \(lent)", bundle: .module),
            fill: .statusFine
          )
          if let days = record.averageDaysOut {
            StatTile(eyebrow: Text("Average out", bundle: .module), figure: Text("\(days) days", bundle: .module))
          }
        }
      }
    }

    func row(_ loan: Loan) -> some View {
      let shelf = store.snapshot.shelf
      let object = shelf.objects[loan.objectID]
      let manifest = object.flatMap { catalogue.manifest($0.typeID) }
      return Button {
        send(.loanTapped(loan.objectID))
      } label: {
        ObjectRow(
          title: Text(verbatim: object.map { $0.title.isEmpty ? "—" : $0.title } ?? ""),
          meta: dates(loan),
          gradient: manifest?.gradient ?? [],
          mark: manifest?.mark ?? "",
          notYours: loan.direction == .in
        ) {
          chip(loan)
        }
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("person.loan.\(object?.title ?? "")")
    }

    func dates(_ loan: Loan) -> Text {
      let format = Date.FormatStyle.dateTime.day().month(.abbreviated).year()
      let opened = loan.openedAt.formatted(format)
      if let closed = loan.closedAt?.formatted(format) {
        return Text(verbatim: "\(opened) – \(closed)")
      }
      if let due = loan.dueAt?.formatted(format) {
        return Text("Since \(opened) · due \(due)", bundle: .module)
      }
      return Text("Since \(opened)", bundle: .module)
    }

    @ViewBuilder
    func chip(_ loan: Loan) -> some View {
      @Dependency(\.date.now) var now
      switch (loan.direction, loan.isOpen) {
      case (.out, true) where loan.isOverdue(at: now): StatusChip(.act, label: Text("Overdue", bundle: .module))
      case (.out, true): StatusChip(.watch, label: Text("Out now", bundle: .module))
      case (.out, false): StatusChip(.fine, label: Text("Returned", bundle: .module))
      case (.in, true): StatusChip(.good, label: Text("Theirs, here", bundle: .module))
      case (.in, false): StatusChip(.fine, label: Text("Given back", bundle: .module))
      }
    }

    /// What to lend them: what's owned, kept and not already out.
    var picker: some View {
      VStack(spacing: 0) {
        ModalBar(Text("What are you lending?", bundle: .module), leaving: .cancel) { send(.pickerDismissed) }
        FieldBox {
          TextField(
            text: Binding(get: { store.query }, set: { send(.queryChanged($0)) }),
            label: { Text("Search your shelf", bundle: .module) }
          )
          .accessibilityIdentifier("person.pick.search")
        }
        .padding(TegolaSpace.gutter)
        ScrollView {
          LazyVStack(spacing: TegolaSpace.s) {
            ForEach(store.lendable) { object in
              let manifest = catalogue.manifest(object.typeID)
              Button {
                send(.objectPicked(object.id))
              } label: {
                ObjectRow(
                  title: Text(verbatim: object.title.isEmpty ? "—" : object.title),
                  meta: Text(verbatim: manifest?.name.noun(for: 1) ?? ""),
                  gradient: manifest?.gradient ?? [],
                  mark: manifest?.mark ?? ""
                )
              }
              .buttonStyle(.plain)
              .accessibilityIdentifier("person.pick.\(object.title)")
            }
          }
          .padding(.horizontal, TegolaSpace.gutter)
        }
      }
      .background(theme[.surface].color)
    }
  }
#endif

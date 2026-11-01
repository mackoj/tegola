#if canImport(SwiftUI)
  public import ComposableArchitecture
  import ReturnFeature
  public import SwiftUI
  import TegolaCatalogue
  import TegolaClients
  import TegolaDesignSystem
  import TegolaDesignTokens
  import TegolaModel
  import TegolaStorage

  /// Boards 17 and 22: *Out of the house*, then *In the house, not yours*.
  @ViewAction(for: ActivityFeature.self)
  public struct ActivityView: View {
    @Bindable public var store: StoreOf<ActivityFeature>
    @Dependency(\.catalogue) var catalogue
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Environment(\.tegolaTheme) private var theme

    public init(store: StoreOf<ActivityFeature>) {
      self.store = store
    }

    public var body: some View {
      let activity = store.activity
      ScrollView {
        VStack(alignment: .leading, spacing: TegolaSpace.l) {
          ScreenHeader(
            eyebrow: activity.isEmpty ? nil : eyebrow(activity),
            title: [Text("Out of", bundle: .module), Text("the house", bundle: .module)]
          )
          if activity.isEmpty {
            EmptyState(
              title: [Text("Nothing out,", bundle: .module), Text("nothing borrowed", bundle: .module)],
              message: Text(
                "Lend something from its page and it shows here, with when it's due back.",
                bundle: .module
              )
            ) { EmptyView() }
          } else {
            FlowLayout(spacing: TegolaSpace.xs) {
              ForEach(ActivityFeature.State.Filter.allCases, id: \.self) { filter in
                Pill(filter.label, isActive: store.filter == filter) { send(.filterTapped(filter)) }
                  .accessibilityIdentifier("activity.filter.\(filter)")
              }
            }
            switch store.filter {
            case .outNow: outNow(activity)
            case .returned: returned(activity)
            case .byPerson: byPerson(activity)
            }
            if !activity.borrowed.isEmpty { borrowed(activity) }
          }
        }
        .padding(.horizontal, TegolaSpace.gutter)
        .padding(.top, TegolaSpace.l)
        .padding(.bottom, TegolaSpace.xxl)
      }
      .background(theme[.surface].color)
      .sheet(item: $store.scope(state: \.returnLoan, action: \.returnLoan)) { sheet in
        ReturnView(store: sheet)
      }
    }

    func eyebrow(_ activity: Activity) -> Text {
      let out = Text("\(activity.out.count) lent", bundle: .module)
      guard activity.overdue > 0 else { return out }
      let late = Text("\(activity.overdue) overdue", bundle: .module)
      return Text("\(out) · \(late)", bundle: .module)
    }

    @ViewBuilder
    func outNow(_ activity: Activity) -> some View {
      if activity.out.isEmpty {
        Text("Nothing's out right now.", bundle: .module)
          .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
      }
      ForEach(activity.out) { loan in card(loan) }
    }

    @ViewBuilder
    func returned(_ activity: Activity) -> some View {
      if activity.returned.isEmpty {
        Text("Nothing has come back yet.", bundle: .module)
          .tegolaTextStyle(TegolaType.body).foregroundStyle(TegolaRole.textMuted)
      }
      ForEach(activity.returned) { loan in
        row(loan, meta: returnedMeta(loan), notYours: false)
      }
    }

    func byPerson(_ activity: Activity) -> some View {
      ForEach(activity.byPerson) { entry in
        Button {
          send(.personTapped(entry.person.id))
        } label: {
          HStack {
            Text(verbatim: entry.person.name).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
            Spacer()
            let count = entry.loans.count
            Text("\(count) out", bundle: .module).tegolaTextStyle(TegolaType.meta)
              .foregroundStyle(TegolaRole.textMeta)
          }
          .padding(TegolaSpace.m)
          .frame(minHeight: TegolaMetrics.minimumHitTarget)
          .printed(radius: TegolaRadius.card)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("activity.person.\(entry.person.name)")
      }
    }

    /// Board 22: someone else's things on the shelf, dashed, never counted.
    @ViewBuilder
    func borrowed(_ activity: Activity) -> some View {
      VStack(alignment: .leading, spacing: TegolaSpace.xs) {
        Text("The other direction", bundle: .module).tegolaTextStyle(TegolaType.meta)
          .foregroundStyle(TegolaRole.textMeta)
        DisplayTitle([Text("In the house,", bundle: .module), Text("not yours", bundle: .module)])
      }
      .padding(.top, TegolaSpace.l)
      ForEach(activity.borrowed) { loan in
        let person = name(loan)
        let since = loan.openedAt.formatted(.dateTime.day().month(.abbreviated).year())
        row(loan, meta: Text("\(person) · since \(since)", bundle: .module), notYours: true)
      }
    }

    /// A loan out (board 17): the object and who has it, over a footer that says how it stands.
    func card(_ loan: Loan) -> some View {
      let state = Standing(loan: loan, now: now, calendar: calendar)
      return VStack(spacing: 0) {
        Button {
          send(.objectTapped(loan.objectID))
        } label: {
          content(loan, meta: outMeta(loan))
            .padding(TegolaSpace.s + 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("activity.loan.\(title(loan))")
        // One row when it fits; the status above the actions when it doesn't (French, large Dynamic Type).
        ViewThatFits(in: .horizontal) {
          HStack(spacing: TegolaSpace.m) {
            state.label.tegolaTextStyle(TegolaType.metaSmall).fixedSize()
            Spacer(minLength: 0)
            actions(loan)
          }
          VStack(alignment: .leading, spacing: 0) {
            state.label.tegolaTextStyle(TegolaType.metaSmall).padding(.top, TegolaSpace.s)
            HStack(spacing: TegolaSpace.m) { actions(loan) }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(state.ink)
        .padding(.horizontal, TegolaSpace.m)
        .background(theme[state.fill].color)
        .overlay(alignment: .top) {
          Rectangle().fill(theme[.edge].color).frame(height: TegolaBorder.standard)
        }
      }
      .printed(radius: TegolaRadius.card)
      .clipShape(RoundedRectangle(cornerRadius: TegolaRadius.card))
    }

    /// A loan's footer actions: Nudge, when there's someone to nudge, and Mark returned.
    @ViewBuilder
    func actions(_ loan: Loan) -> some View {
      if let nudge = Nudge(loan: loan.id, shelf: store.snapshot.shelf, now: now, calendar: calendar) {
        // F13: Nudge opens the share sheet with a friendly line; there's no link to send in v1 (PD-160).
        ShareLink(item: Self.line(for: nudge)) {
          TegolaAction.nudge.label.tegolaTextStyle(TegolaType.label).underline().fixedSize()
        }
        .buttonStyle(.plain)
        .frame(minHeight: TegolaMetrics.minimumHitTarget)
        .accessibilityIdentifier("activity.nudge.\(title(loan))")
      }
      Button {
        send(.markReturnedTapped(loan.id))
      } label: {
        TegolaAction.returnLoan.label.tegolaTextStyle(TegolaType.label).underline().fixedSize()
      }
      .buttonStyle(.plain)
      .frame(minHeight: TegolaMetrics.minimumHitTarget)
      .accessibilityIdentifier("activity.return.\(title(loan))")
    }

    func row(_ loan: Loan, meta: Text, notYours: Bool) -> some View {
      Button {
        send(.objectTapped(loan.objectID))
      } label: {
        let object = store.snapshot.shelf.objects[loan.objectID]
        let manifest = object.flatMap { catalogue.manifest($0.typeID) }
        ObjectRow(
          title: Text(verbatim: title(loan)),
          meta: meta,
          gradient: manifest?.gradient ?? [],
          mark: manifest?.mark ?? "",
          notYours: notYours
        )
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("activity.row.\(title(loan))")
    }

    func content(_ loan: Loan, meta: Text) -> some View {
      let object = store.snapshot.shelf.objects[loan.objectID]
      let manifest = object.flatMap { catalogue.manifest($0.typeID) }
      return HStack(spacing: TegolaSpace.m) {
        TypeTint(gradient: manifest?.gradient ?? [], mark: manifest?.mark ?? "", markStyle: TegolaType.metaSmall)
          .frame(width: 52, height: 52)
          .clipShape(RoundedRectangle(cornerRadius: TegolaRadius.badge))
          .overlay(RoundedRectangle(cornerRadius: TegolaRadius.badge).strokeBorder(lineWidth: TegolaBorder.standard))
        VStack(alignment: .leading, spacing: 3) {
          Text(verbatim: title(loan)).tegolaTextStyle(TegolaType.heading).foregroundStyle(TegolaRole.text)
          meta.tegolaTextStyle(TegolaType.metaSmall).foregroundStyle(TegolaRole.textMeta)
          if !loan.note.isEmpty {
            Text(verbatim: loan.note).tegolaTextStyle(TegolaType.body).italic().foregroundStyle(TegolaRole.textMuted)
              .lineLimit(2)
          }
        }
        Spacer(minLength: 0)
      }
      .contentShape(Rectangle())
    }

    /// The nudge's friendly line (F13, board 21): the object, how long, and no pressure. Never a price (promise 5).
    static func line(for nudge: Nudge) -> String {
      let person = nudge.person
      let title = nudge.title
      if let late = nudge.daysOverdue {
        return String(
          localized: "Hi \(person)! Just checking in on \(title): it was due back \(late) days ago. No rush, tell me when.",
          bundle: .module
        )
      }
      return String(
        localized: "Hi \(person)! Hope you're enjoying \(title). Tell me when you're done with it.",
        bundle: .module
      )
    }

    func title(_ loan: Loan) -> String {
      let title = store.snapshot.shelf.objects[loan.objectID]?.title ?? ""
      return title.isEmpty ? "—" : title
    }

    func name(_ loan: Loan) -> String { store.snapshot.shelf.persons[loan.personID]?.name ?? "" }

    func outMeta(_ loan: Loan) -> Text {
      let person = name(loan)
      guard let due = loan.dueAt?.formatted(.dateTime.day().month(.abbreviated)) else {
        return Text("\(person) · no return date", bundle: .module)
      }
      return Text("\(person) · back by \(due)", bundle: .module)
    }

    func returnedMeta(_ loan: Loan) -> Text {
      let person = name(loan)
      let back = (loan.closedAt ?? loan.openedAt).formatted(.dateTime.day().month(.abbreviated).year())
      return Text("\(person) · back \(back)", bundle: .module)
    }
  }

  /// How a loan out stands, for its footer (board 17): overdue in rust, due within a week in yellow, else plain.
  struct Standing {
    let label: Text
    let fill: TegolaRole
    let ink: TegolaRole

    init(loan: Loan, now: Date, calendar: Calendar) {
      func days(_ from: Date, _ to: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day
          ?? 0
      }
      if let due = loan.dueAt {
        let left = days(now, due)
        if loan.isOverdue(at: now) {
          let late = max(1, -left)
          label = Text("Overdue · \(late) days", bundle: .module)
          fill = .accentLoss
          ink = .onAccentLoss
        } else if left == 0 {
          label = Text("Due today", bundle: .module)
          (fill, ink) = (.accentHighlight, .onAccentHighlight)
        } else {
          label = Text("Due in \(left) days", bundle: .module)
          (fill, ink) = left <= 7 ? (.accentHighlight, .onAccentHighlight) : (.surfaceSunken, .text)
        }
      } else {
        let out = max(0, days(loan.openedAt, now))
        label = Text("Out · \(out) days", bundle: .module)
        (fill, ink) = (.surfaceSunken, .text)
      }
    }
  }

  extension ActivityFeature.State.Filter {
    var label: Text {
      switch self {
      case .outNow: Text("Out now", bundle: .module)
      case .returned: Text("Returned", bundle: .module)
      case .byPerson: Text("By person", bundle: .module)
      }
    }
  }
#endif

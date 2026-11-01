public import ComposableArchitecture
public import Foundation
public import LendFeature
public import SQLiteData
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// One person (F13, board 19): what they hold now, how lending to them has gone, every loan both ways, and **Lend them
/// something**, which picks an object and opens the lend sheet with them already chosen.
@Reducer
public struct PersonFeature {
  @ObservableState
  public struct State: Equatable {
    public let id: PersonID
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    /// Choosing what to lend them; the lend sheet replaces the list in the same sheet.
    public var isPicking = false
    public var query = ""
    @Presents public var lend: LendFeature.State?

    public init(id: PersonID) {
      self.id = id
    }

    public var record: PersonRecord? {
      @Dependency(\.calendar) var calendar
      return PersonRecord(person: id, shelf: snapshot.shelf, calendar: calendar)
    }

    /// What can be lent now: owned, kept, one copy each, not already out (promise 6). Filtered by the query.
    public var lendable: [ShelfObject] {
      let shelf = snapshot.shelf
      let query = query.trimmingCharacters(in: .whitespaces)
      return shelf.objects.values
        .filter { $0.counts && $0.bulk == .rows && shelf.openLoan(on: $0.id) == nil }
        .filter { query.isEmpty || $0.title.localizedStandardContains(query) }
        .sorted { ($0.title.localizedLowercase, $0.id) < ($1.title.localizedLowercase, $1.id) }
    }

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id && lhs.isPicking == rhs.isPicking && lhs.query == rhs.query && lhs.lend == rhs.lend
    }
  }

  public enum Action: ViewAction {
    case delegate(Delegate)
    case lend(PresentationAction<LendFeature.Action>)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      case open(Route)
    }

    public enum View: Equatable {
      case lendSomethingTapped
      case loanTapped(ObjectID)
      case objectPicked(ObjectID)
      case pickerDismissed
      case queryChanged(String)
    }
  }

  @Dependency(\.date.now) var now

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none
      case .lend(.dismiss):
        // The lend sheet is done, or cancelled: the whole sheet closes.
        state.isPicking = false
        state.query = ""
        return .none
      case .lend:
        return .none
      case .view(.lendSomethingTapped):
        state.isPicking = true
        return .none
      case .view(.loanTapped(let id)):
        return .send(.delegate(.open(.object(id))))
      case .view(.objectPicked(let id)):
        let shelf = state.snapshot.shelf
        guard let object = shelf.objects[id] else { return .none }
        var sheet = LendFeature.State(
          objectID: id,
          title: object.title,
          mode: .lend,
          people: shelf.recentPeople,
          now: now
        )
        sheet.person = state.id
        sheet.isNew = false
        state.lend = sheet
        return .none
      case .view(.pickerDismissed):
        state.isPicking = false
        state.query = ""
        state.lend = nil
        return .none
      case .view(.queryChanged(let query)):
        state.query = query
        return .none
      }
    }
    .ifLet(\.$lend, action: \.lend) { LendFeature() }
  }
}

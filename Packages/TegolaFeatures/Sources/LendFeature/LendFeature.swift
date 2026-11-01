public import ComposableArchitecture
public import Foundation
import TegolaClients
public import TegolaModel

/// Lend in three taps (F13, board 18): who, back by when, **Hand it over**. The note is optional (PD-123). The same
/// sheet says whose a borrowed object is (`borrow`), with no date and no note (PD-061).
@Reducer
public struct LendFeature {
  @ObservableState
  public struct State: Equatable {
    public enum Mode: Equatable, Sendable {
      /// The collector's object goes out.
      case lend
      /// Someone else's object is on the shelf: whose is it?
      case borrow
    }

    /// When it's due back. Two weeks is the default (board 18).
    public enum Due: Hashable, Sendable, CaseIterable {
      case twoWeeks, oneMonth, date, none
    }

    public let objectID: ObjectID
    public let title: String
    public let mode: Mode
    /// The people to pick from, the most recently used first.
    public let people: [Person]
    public var person: PersonID?
    /// Typing a name for someone new; the only way when nobody's on the shelf yet.
    public var isNew: Bool
    public var newName = ""
    public var due: Due = .twoWeeks
    /// The date picked when `due` is `date`.
    public var date: Date
    public var note = ""
    public var refusal: ShelfRuleViolation?

    public init(objectID: ObjectID, title: String, mode: Mode, people: [Person], now: Date) {
      self.objectID = objectID
      self.title = title
      self.mode = mode
      self.people = people
      isNew = people.isEmpty
      date = now.addingTimeInterval(14 * 86_400)
    }

    /// Who it's with, once there's someone to name.
    public var choice: PersonChoice? {
      if isNew {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : .new(name: name)
      }
      return person.map(PersonChoice.existing)
    }

    public var canSubmit: Bool { choice != nil }
  }

  public enum Action: ViewAction {
    case refused(ShelfRuleViolation)
    case succeeded
    case view(View)

    public enum View: Equatable {
      case cancelTapped
      case dateChanged(Date)
      case dueTapped(State.Due)
      case newNameChanged(String)
      case newTapped
      case noteChanged(String)
      case personTapped(PersonID)
      case submitTapped
    }
  }

  @Dependency(\.calendar) var calendar
  @Dependency(\.date.now) var now
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .refused(let violation):
        state.refusal = violation
        return .none
      case .succeeded:
        return .run { [dismiss] _ in await dismiss() }
      case .view(.cancelTapped):
        return .run { [dismiss] _ in await dismiss() }
      case .view(.dateChanged(let date)):
        state.date = date
        return .none
      case .view(.dueTapped(let due)):
        state.due = due
        return .none
      case .view(.newNameChanged(let name)):
        state.newName = name
        state.refusal = nil
        return .none
      case .view(.newTapped):
        state.isNew = true
        state.person = nil
        return .none
      case .view(.noteChanged(let note)):
        state.note = note
        return .none
      case .view(.personTapped(let id)):
        state.person = id
        state.isNew = false
        state.refusal = nil
        return .none
      case .view(.submitTapped):
        guard let choice = state.choice else { return .none }
        let command: ShelfCommand =
          switch state.mode {
          case .lend:
            .lend(
              state.objectID,
              to: choice,
              due: dueDate(state),
              note: state.note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
          case .borrow: .markBorrowed(state.objectID, from: choice)
          }
        return .run { [shelf] send in
          do {
            _ = try shelf.perform(command)
            await send(.succeeded)
          } catch let violation as ShelfRuleViolation {
            await send(.refused(violation))
          } catch {
            reportIssue(error)
          }
        }
      }
    }
  }

  /// The due date the choice names, in the collector's calendar. A loan is due back on a day, not at a time: the date
  /// stored is the last moment of that day, so it's overdue only once the day is over (review of M7, finding 1).
  func dueDate(_ state: State) -> Date? {
    let day: Date? =
      switch state.due {
      case .twoWeeks: calendar.date(byAdding: .day, value: 14, to: now)
      case .oneMonth: calendar.date(byAdding: .month, value: 1, to: now)
      case .date: max(state.date, now)
      case .none: nil
      }
    return day.flatMap { Self.endOfDay($0, calendar: calendar) }
  }

  /// The last second of `date`'s day.
  static func endOfDay(_ date: Date, calendar: Calendar) -> Date? {
    calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: date))
  }
}

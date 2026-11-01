public import ComposableArchitecture
public import Foundation
import TegolaClients
public import TegolaModel

/// Closing a loan (F13, board 20): how it came back, a note for the record, and what gets written. The collector closes
/// it alone, and the history says so (PD-160).
@Reducer
public struct ReturnFeature {
  @ObservableState
  public struct State: Equatable {
    public let loanID: LoanID
    /// The object, who had it, how long and how late: the sheet's card.
    public let nudge: Nudge
    /// Board 20 starts on *Came back in the same shape*.
    public var cameBack: Loan.CameBack? = .sameShape
    public var note = ""
    public var refusal: ShelfRuleViolation?

    public init(loanID: LoanID, nudge: Nudge) {
      self.loanID = loanID
      self.nudge = nudge
    }

    /// Nil unless the loan is open and out.
    public init?(loan id: LoanID, shelf: Shelf, now: Date, calendar: Calendar) {
      guard let nudge = Nudge(loan: id, shelf: shelf, now: now, calendar: calendar) else { return nil }
      self.init(loanID: id, nudge: nudge)
    }

    /// The note as it will be written: trimmed, and none when blank.
    public var words: String? {
      let words = note.trimmingCharacters(in: .whitespacesAndNewlines)
      return words.isEmpty ? nil : words
    }
  }

  public enum Action: ViewAction {
    case refused(ShelfRuleViolation)
    case succeeded
    case view(View)

    public enum View: Equatable {
      case cameBackTapped(Loan.CameBack)
      case cancelTapped
      case itsHomeTapped
      case noteChanged(String)
    }
  }

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
      case .view(.cameBackTapped(let cameBack)):
        // Tapping the chosen answer again leaves it unsaid.
        state.cameBack = state.cameBack == cameBack ? nil : cameBack
        return .none
      case .view(.cancelTapped):
        return .run { [dismiss] _ in await dismiss() }
      case .view(.itsHomeTapped):
        let command = ShelfCommand.returnLoan(state.loanID, cameBack: state.cameBack, condition: state.words)
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
      case .view(.noteChanged(let note)):
        state.note = note
        return .none
      }
    }
  }
}

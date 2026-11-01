public import ComposableArchitecture
public import Foundation
public import SQLiteData
import TegolaCatalogue
public import TegolaClients
public import TegolaModel
public import TegolaStorage

/// The review queue (F8, T6.11): what's left to confirm, grouped by how sure the lookup is, each with why. Confirming
/// fills only empty fields from the candidate, then confirms; **Confirm all** takes strong matches only. Nothing is
/// confirmed, merged or overwritten on the collector's behalf (PD-042, PD-045, PD-151).
@Reducer
public struct ReviewFeature {
  @ObservableState
  public struct State: Equatable {
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    public var queue = LookupQueue()
    /// The candidate the collector picked for a row that asked ("Which Tetris?").
    public var picked: [ObjectID: String] = [:]

    public init() {}

    public var review: ReviewQueue {
      @Dependency(\.catalogue) var catalogue
      return ReviewQueue(shelf: snapshot.shelf, queue: queue, catalogue: catalogue)
    }

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.queue == rhs.queue && lhs.picked == rhs.picked
    }
  }

  public enum Action: ViewAction {
    case delegate(Delegate)
    case loaded(LookupQueue)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      case open(Route)
    }

    @CasePathable
    public enum View: Equatable {
      case candidatePicked(ObjectID, releaseID: String)
      case confirmAllTapped
      case confirmTapped(ObjectID)
      case fillInTapped(ObjectID)
      case onAppear
      case openYoursTapped(ObjectID)
    }
  }

  @Dependency(\.catalogue) var catalogue
  @Dependency(\.lookupQueue) var lookupQueue
  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none

      case .loaded(let queue):
        state.queue = queue
        return .none

      case .view(.candidatePicked(let id, let release)):
        state.picked[id] = release
        return .none

      case .view(.confirmAllTapped):
        let commands = state.review.confirmAll
        return .run { [shelf, lookupQueue] send in
          for command in commands {
            // A lookup's values come from the lookup; the confirmation is the collector's (PD-042).
            if case .applyLookup = command { _ = try shelf.perform(command, .lookup) } else { _ = try shelf.perform(command) }
          }
          await send(.loaded(try lookupQueue.load()))
        } catch: { error, _ in
          reportIssue(error)
        }

      case .view(.confirmTapped(let id)):
        guard let row = state.review.rows.first(where: { $0.id == id }) else { return .none }
        let candidate = state.picked[id].flatMap { release in row.candidates.first { $0.releaseID == release } }
        let proposal =
          candidate.map {
            EnrichmentProposal(object: id, candidate: $0, shelf: state.snapshot.shelf, catalogue: catalogue)
          } ?? row.proposal
        // Needs details can't be confirmed without a title: Fill in first.
        guard row.object.identity != .needsDetails || (proposal?.changes[.title] != nil) || !row.object.title.isEmpty
        else { return .send(.delegate(.open(.object(id)))) }
        return .run { [shelf, lookupQueue] send in
          if let proposal, proposal.fits { _ = try shelf.perform(proposal.apply(), .lookup) }
          _ = try shelf.perform(.confirm([id]))
          await send(.loaded(try lookupQueue.load()))
        } catch: { error, _ in
          reportIssue(error)
        }

      case .view(.fillInTapped(let id)), .view(.openYoursTapped(let id)):
        return .send(.delegate(.open(.object(id))))

      case .view(.onAppear):
        return .run { [lookupQueue] send in
          await send(.loaded(try lookupQueue.load()))
        } catch: { error, _ in
          reportIssue(error)
        }
      }
    }
  }
}

public import ComposableArchitecture
public import Foundation
import SQLiteData
import TegolaCatalogue
public import TegolaClients
public import TegolaInterchange
public import TegolaModel
import TegolaStorage

/// Bringing a list (PLAN F9, page 49; T6.10): pick a file, read it, say in one sentence what it is, build the shelf in
/// one write, then match the rows in the background. Nothing is confirmed on the collector's behalf: every row lands
/// unconfirmed, and the whole batch can be undone for 30 days (PD-047, D-64).
@Reducer
public struct ImportFeature {
  @ObservableState
  public struct State: Equatable {
    public var step: Step = .pick
    public var fileName = ""
    public var file: Data?
    public var plan: ImportPlan?
    /// The importers that can read the file, most certain first: **Something's off** offers the others.
    public var importers: [ImporterID] = []
    public var collectionName = ""
    public var batch: BatchID?
    public var objects: [ObjectID] = []
    /// Rows the server matched or asked about, once matching is done.
    public var matched: Int?
    public var undone: Undone?
    public var isUndoing = false
    public var failed = false

    public init() {}

    public enum Step: Hashable, Sendable {
      /// **Import a list**: the file picker.
      case pick
      case reading
      /// The one sentence (49 §02), with rename, **Build my shelf** and **Something's off**.
      case sentence
      case building
      /// The payoff (49 §05), with undo.
      case payoff
    }

    public struct Undone: Hashable, Sendable {
      public var removed: Int
      public var kept: Int
    }
  }

  public enum Action: ViewAction {
    case built(BatchID, [ObjectID])
    case buildFailed
    case delegate(Delegate)
    case matchedRows(Int)
    case planned(ImportPlan, [ImporterID])
    case planFailed
    case undone(removed: Int, kept: Int)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      /// The rows are on the shelf: the app opens their collection.
      case finished(CollectionID?)
      /// Match these rows in the background: the app runs it, so closing the sheet doesn't stop it (D-74).
      case match([ImportPlan.Row], [ObjectID])
    }

    @CasePathable
    public enum View: Equatable {
      case buildTapped
      case closeTapped
      case doneTapped
      case fileChosen(name: String, data: Data)
      case importerTapped(ImporterID)
      case renamed(String)
      case undoTapped
    }
  }

  @Dependency(\.catalogue) var catalogue
  @Dependency(\.date.now) var now
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.lookup) var lookup
  @Dependency(\.lookupQueue) var lookupQueue
  @Dependency(\.shelf) var shelf

  public init() {}

  /// The v1 importers; tests can't swap them, as every importer is pure and pinned by its own tests.
  static let registry = ImporterRegistry.v1

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .built(let batch, let objects):
        state.batch = batch
        state.objects = objects
        state.step = .payoff
        guard let plan = state.plan else { return .none }
        return .send(.delegate(.match(plan.rows, objects)))

      case .buildFailed:
        state.step = .sentence
        state.failed = true
        return .none

      case .delegate:
        return .none

      case .matchedRows(let count):
        state.matched = count
        return .none

      case .planned(let plan, let importers):
        state.plan = plan
        state.importers = importers
        state.collectionName = plan.collectionName
        state.step = .sentence
        state.failed = false
        return .none

      case .planFailed:
        state.step = .pick
        state.failed = true
        return .none

      case .undone(let removed, let kept):
        state.isUndoing = false
        state.undone = State.Undone(removed: removed, kept: kept)
        return .none

      case .view(.buildTapped):
        guard var plan = state.plan, state.step == .sentence else { return .none }
        let name = state.collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { plan.collectionName = name }
        state.plan = plan
        state.step = .building
        let batch = plan.batch()
        return .run { [shelf] send in
          let receipt = try shelf.perform(.importBatch(batch), .import)
          guard let id = receipt.batchID else { return await send(.buildFailed) }
          await send(.built(id, receipt.createdObjects))
        } catch: { error, send in
          reportIssue(error)
          await send(.buildFailed)
        }

      case .view(.closeTapped), .view(.doneTapped):
        let collection = state.objects.first.flatMap { _ in state.collectionID }
        return .run { [dismiss] send in
          if collection != nil { await send(.delegate(.finished(collection))) }
          await dismiss()
        }

      case .view(.fileChosen(let name, let data)):
        state.fileName = name
        state.file = data
        state.step = .reading
        return read(name: name, data: data, importer: nil)

      case .view(.importerTapped(let importer)):
        guard let data = state.file else { return .none }
        state.step = .reading
        return read(name: state.fileName, data: data, importer: importer)

      case .view(.renamed(let name)):
        state.collectionName = name
        return .none

      case .view(.undoTapped):
        guard let batch = state.batch, state.undone == nil, !state.isUndoing else { return .none }
        state.isUndoing = true
        return .run { [shelf] send in
          let receipt = try shelf.perform(.undoBatch(batch))
          for event in receipt.events {
            if case .batchUndone(_, let removed, let kept) = event.kind {
              await send(.undone(removed: removed.count, kept: kept.count))
            }
          }
        } catch: { error, _ in
          reportIssue(error)
        }
      }
    }
  }

  /// Reads the file with the importer that recognises it best, or the one the collector picked. Cells are read by the
  /// rule-based reader on every device (D-74).
  func read(name: String, data: Data, importer chosen: ImporterID?) -> Effect<Action> {
    .run { [catalogue] send in
      let input = ImportInput(fileName: name, data: data)
      let candidates = Self.registry.candidates(for: input).map(\.importer)
      guard let importer = candidates.first(where: { $0.id == chosen }) ?? candidates.first else {
        return await send(.planFailed)
      }
      let plan = try await importer.plan(input, catalogue: catalogue, extraction: NoteReader())
      guard !plan.rows.isEmpty else { return await send(.planFailed) }
      await send(.planned(plan, candidates.map(\.id)))
    } catch: { error, send in
      reportIssue(error)
      await send(.planFailed)
    }
  }
}

extension ImportFeature.State {
  /// The collection the rows landed in.
  var collectionID: CollectionID? {
    @Dependency(\.defaultDatabase) var database
    guard let first = objects.first else { return nil }
    return try? database.read { db in try ShelfRequest().fetch(db) }.shelf.objects[first]?.collectionID
  }
}

public import ComposableArchitecture
public import Foundation
public import SQLiteData
public import TegolaCatalogue
public import TegolaClients
public import TegolaModel
public import TegolaStorage

/// The Scan tab's camera (PLAN F6, T6.9): it reads barcodes and text live; a shot saves an object at once, before any
/// network, into **Add to**; the camera stays open and the object goes to the tray. What it read is queued for a
/// lookup. **Identify?** sends this one shot's photo with what was read, and is off again for the next (D-71).
@Reducer
public struct CaptureFeature {
  @ObservableState
  public struct State: Equatable {
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    /// The type the next shot is, and where it goes.
    public var type: TypeManifest.ID?
    public var collection: CollectionChoice?
    /// What the camera reads now: the shutter saves with it.
    public var seen: Seen?
    /// Per shot, off by default (PD-118).
    public var identify = false
    /// The objects added since the camera opened, newest first.
    public var tray: [TrayItem] = []
    public var isSaving = false

    public init(type: TypeManifest.ID? = nil) {
      self.type = type
    }

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.type == rhs.type && lhs.collection == rhs.collection && lhs.seen == rhs.seen
        && lhs.identify == rhs.identify && lhs.tray == rhs.tray && lhs.isSaving == rhs.isSaving
    }

    /// Where a shot of `type` goes: the last collection used if it takes the type, else the type's own, else a new one
    /// named by the type (PD-137), as Add by hand does.
    func defaultCollection(for type: TypeManifest.ID, catalogue: Catalogue) -> CollectionChoice {
      let shelf = snapshot.shelf
      if let last = snapshot.lastCollection, let collection = shelf.collections[last],
        collection.typeID == nil || collection.typeID == type
      {
        return .existing(last)
      }
      if let own = shelf.collections.values.filter({ $0.typeID == type }).min(by: { $0.sortKey < $1.sortKey }) {
        return .existing(own.id)
      }
      return .new(name: catalogue.manifest(type)?.name.collection ?? type.rawValue)
    }
  }

  /// What the live camera recognised.
  public enum Seen: Hashable, Sendable {
    case barcode(String)
    /// The text it reads, newline-separated: a spine, a label.
    case text(String)

    var identifier: LookupQueue.Request.Identifier {
      switch self {
      case .barcode(let code): .barcode(code)
      case .text(let text): .text(text)
      }
    }

    var hints: LookupHints {
      switch self {
      case .barcode(let code): LookupHints(barcode: code)
      case .text(let text): LookupHints(text: text)
      }
    }
  }

  /// One object in the tray: what it was saved from, and what the lookup said so far.
  public struct TrayItem: Hashable, Sendable, Identifiable {
    public let id: ObjectID
    public var seen: Seen?
    public var status: Status

    public enum Status: Hashable, Sendable {
      /// Saved; the lookup waits for the network.
      case queued
      /// Identify is asking the server now.
      case identifying
      /// The best candidate's title, to confirm in the review queue (F8).
      case proposed(String)
      /// Nothing found: it needs details.
      case nothingFound
    }
  }

  public enum Action: ViewAction {
    case delegate(Delegate)
    case identified(ObjectID, [LookupCandidate]?)
    case saved(ObjectID, Seen?, CollectionID?, identifying: Bool)
    case saveFailed
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      /// Something was queued: the app starts the lookup worker.
      case queued
      case review
      /// **Type it**: the add form instead of the camera.
      case typeIt
    }

    @CasePathable
    public enum View: Equatable {
      case closeTapped
      case collectionTapped(CollectionChoice)
      case identifyToggled(Bool)
      case recognised(Seen?)
      case shutterTapped(photo: Data?)
      case trayItemTapped(ObjectID)
      case typeItTapped
      case typeTapped(TypeManifest.ID)
    }
  }

  @Dependency(\.catalogue) var catalogue
  @Dependency(\.date.now) var now
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.lookup) var lookup
  @Dependency(\.lookupQueue) var lookupQueue
  @Dependency(\.photoStore) var photoStore
  @Dependency(\.settings) var settings
  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none

      case .identified(let id, let candidates):
        guard let index = state.tray.firstIndex(where: { $0.id == id }) else { return .none }
        switch candidates {
        case .some(let candidates):
          let best = candidates.max { $0.confidence < $1.confidence }
          state.tray[index].status =
            best.flatMap { candidate in
              if case .text(let title) = candidate.values[.title] { .proposed(title) } else { nil }
            } ?? .nothingFound
        case .none:
          // Identify failed (offline, or the server refused): what was read waits in the queue as before.
          state.tray[index].status = .queued
        }
        return .none

      case .saved(let id, let seen, let collection, let identifying):
        state.isSaving = false
        // The next shot goes where this one went: a new collection is made once, not once a shot.
        if let collection { state.collection = .existing(collection) }
        state.tray.insert(TrayItem(id: id, seen: seen, status: identifying ? .identifying : .queued), at: 0)
        return .none

      case .saveFailed:
        state.isSaving = false
        return .none

      case .view(.closeTapped):
        return .run { [dismiss] _ in await dismiss() }

      case .view(.collectionTapped(let choice)):
        state.collection = choice
        return .none

      case .view(.identifyToggled(let on)):
        state.identify = on
        return .none

      case .view(.recognised(let seen)):
        state.seen = seen
        return .none

      case .view(.shutterTapped(let photo)):
        guard let type = state.type, let collection = state.collection, !state.isSaving else { return .none }
        state.isSaving = true
        let seen = state.seen
        // Identify is per shot: it's off again for the next one (PD-118).
        let identify = state.identify && photo != nil
        state.identify = false
        let draft = ObjectDraft(type: type, needsDetails: true)
        return .run { [shelf, settings, photoStore, lookup, lookupQueue, now] send in
          // Saved before any network: the object, the shot, and what was read, queued in the same transaction.
          let receipt = try shelf.capture(.add(draft, to: collection, origin: .captured), seen?.identifier)
          guard let id = receipt.createdObjects.first else { return await send(.saveFailed) }
          if let photo {
            do {
              let file = try photoStore.save(photo)
              _ = try shelf.perform(.attachPhoto(id, fileName: file, takenAt: now), .capture)
            } catch {
              reportIssue(error)
            }
          }
          if let added = receipt.collectionID { try? settings.set(.lastCollection, added.rawValue.uuidString) }
          await send(.saved(id, seen, receipt.collectionID, identifying: identify))
          // With Identify, what was read goes out with the photo; the worker gets it only if Identify can't answer.
          guard identify, let photo else { return await send(.delegate(.queued)) }
          let hints = seen?.hints ?? LookupHints()
          do {
            let candidates = try await lookup.identify(type, hints, photo)
            // The answer goes where the worker's would: on the object's queued request, for the review queue.
            let queued = try lookupQueue.load().requests.first { $0.objectID == id && $0.state == .waiting }
            if let queued {
              try lookupQueue.record(queued.id, .answered(candidates), now)
            } else {
              try lookupQueue.answer(id, candidates, now)
            }
            await send(.identified(id, candidates))
          } catch {
            await send(.identified(id, nil))
            await send(.delegate(.queued))
          }
        } catch: { error, send in
          reportIssue(error)
          await send(.saveFailed)
        }

      case .view(.trayItemTapped):
        // "Confirm it in Review" (D-75): the review queue, where the tray's objects wait.
        return .send(.delegate(.review))

      case .view(.typeItTapped):
        return .send(.delegate(.typeIt))

      case .view(.typeTapped(let type)):
        state.type = type
        state.collection = state.defaultCollection(for: type, catalogue: catalogue)
        return .none
      }
    }
  }
}

extension CommandReceipt {
  /// The collection the add put its object in, from its `added` event.
  var collectionID: CollectionID? {
    events.lazy.compactMap { event -> CollectionID? in
      if case .added(let object, _) = event.kind { object.collectionID } else { nil }
    }.first
  }
}

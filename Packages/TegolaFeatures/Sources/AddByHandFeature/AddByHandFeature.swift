public import ComposableArchitecture
import Foundation
public import SQLiteData
public import TegolaCatalogue
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// Adding an object by hand (F6, the Scan sheet's Type it; board 12): pick the type, then fill the same form as Edit.
/// Add to points at the last collection used; the first object of a type creates its collection ("My Music", PD-137).
/// "Save and add another" keeps the type and the collection, for thirty objects in one sitting (M3's exit test).
@Reducer
public struct AddByHandFeature {
  @ObservableState
  public struct State: Equatable {
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    public var type: TypeManifest.ID?
    public var subtype: String?
    public var draft: [FieldKey: FieldValue] = [:]
    public var place = ""
    public var revealed: Set<String> = []
    public var collection: CollectionChoice?
    public var refusal: ShelfRuleViolation?
    /// Objects added since the sheet opened.
    public var added = 0

    public init() {}

    public var canSave: Bool {
      if case .text(let title) = draft[.title] {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      } else {
        false
      }
    }

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.type == rhs.type && lhs.subtype == rhs.subtype && lhs.draft == rhs.draft && lhs.place == rhs.place
        && lhs.revealed == rhs.revealed && lhs.collection == rhs.collection && lhs.refusal == rhs.refusal
        && lhs.added == rhs.added
    }

    /// Where a new object of `type` goes: the last collection used, if it takes this type; else the type's own
    /// collection; else a new one named by the type (PD-137).
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

  public enum Action: ViewAction {
    case delegate(Delegate)
    case saveRefused(ShelfRuleViolation)
    case saveSucceeded(ObjectID, CollectionID, addAnother: Bool)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      case added(ObjectID)
    }

    public enum View: Equatable {
      case addTapped(String)
      case changeTypeTapped
      case closeTapped
      case collectionTapped(CollectionChoice)
      case placeChanged(String)
      case saveTapped(addAnother: Bool)
      case subtypeTapped(String?)
      case typeTapped(TypeManifest.ID)
      case valueChanged(FieldKey, FieldValue?)
    }
  }

  @Dependency(\.catalogue) var catalogue
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.settings) var settings
  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none
      case .saveRefused(let violation):
        state.refusal = violation
        return .none
      case .saveSucceeded(let id, let collection, let addAnother):
        state.added += 1
        guard addAnother else {
          return .run { [dismiss] send in
            await send(.delegate(.added(id)))
            await dismiss()
          }
        }
        state.draft = [:]
        state.place = ""
        state.revealed = []
        state.refusal = nil
        state.collection = .existing(collection)
        return .none
      case .view(.addTapped(let key)):
        state.revealed.insert(key)
        return .none
      case .view(.changeTypeTapped):
        state.type = nil
        state.subtype = nil
        state.draft = [:]
        state.refusal = nil
        return .none
      case .view(.closeTapped):
        return .run { [dismiss] _ in await dismiss() }
      case .view(.collectionTapped(let choice)):
        state.collection = choice
        return .none
      case .view(.placeChanged(let place)):
        state.place = place
        return .none
      case .view(.saveTapped(let addAnother)):
        guard let type = state.type, let collection = state.collection else { return .none }
        let draft = ObjectDraft(type: type, subtype: state.subtype, values: state.draft)
        let place = PlacePath(typed: state.place)
        return .run { [shelf, settings] send in
          do {
            let receipt = try shelf.perform(.add(draft, to: collection, origin: .typed))
            guard let id = receipt.createdObjects.first,
              let added = receipt.events.lazy.compactMap({ event -> CollectionID? in
                if case .added(let object, _) = event.kind { object.collectionID } else { nil }
              }).first
            else { return }
            // The object is saved. A place or the remembered collection failing after that is reported, never a reason
            // to save again (a second tap would add a duplicate).
            do {
              if let place { _ = try shelf.perform(.setPlace([id], place)) }
              try settings.set(.lastCollection, added.rawValue.uuidString)
            } catch {
              reportIssue(error)
            }
            await send(.saveSucceeded(id, added, addAnother: addAnother))
          } catch let violation as ShelfRuleViolation {
            await send(.saveRefused(violation))
          } catch {
            reportIssue(error)
          }
        }
      case .view(.subtypeTapped(let subtype)):
        state.subtype = subtype
        // A subtype's additions don't exist on another subtype, and its presets hide fields: start the draft over.
        state.draft = state.draft.filter { key, _ in
          if case .field = key { false } else if case .axis = key { false } else { true }
        }
        return .none
      case .view(.typeTapped(let type)):
        state.type = type
        state.subtype = nil
        state.draft = [:]
        state.place = ""
        state.revealed = []
        state.collection = state.defaultCollection(for: type, catalogue: catalogue)
        return .none
      case .view(.valueChanged(let key, let value)):
        state.draft[key] = value
        state.refusal = nil
        return .none
      }
    }
  }
}

public import ComposableArchitecture
import Foundation
public import TegolaCatalogue
import TegolaClients
public import TegolaModel

/// The edit form (F5, board 13): a separate form with Cancel and Save over a draft of the object's values. Cancel
/// writes nothing; Save sends one `edit` with the changed keys, so history gains one `edited` event naming exactly
/// them (PD-050). A new place is a second command, `setPlace`, and its own history line.
@Reducer
public struct ObjectEditFeature {
  @ObservableState
  public struct State: Equatable {
    public let id: ObjectID
    public let typeID: TypeManifest.ID
    public let subtype: String?
    public let money: MoneyVisibility
    /// The values as the object has them.
    public let original: [FieldKey: FieldValue]
    /// The values as the form holds them.
    public var draft: [FieldKey: FieldValue]
    /// Keys a lookup filled: badged AUTO until the form changes them.
    public let auto: Set<FieldKey>
    public let originalPlace: String
    /// The place, as typed: "Office › Shelf 2".
    public var place: String
    /// Item-level fields "+ Add" has revealed, before they have a value.
    public var revealed: Set<String> = []
    /// What the rules refused, shown in the form until the next change.
    public var refusal: ShelfRuleViolation?

    public init(object: ShelfObject, placePath: String?, money: MoneyVisibility) {
      id = object.id
      typeID = object.typeID
      subtype = object.subtype
      self.money = money
      original = object.values
      draft = object.values
      auto = object.auto
      originalPlace = placePath ?? ""
      place = placePath ?? ""
    }

    /// The keys the form changed, with their new values (nil clears one).
    public var changes: [FieldKey: FieldValue?] {
      var changes: [FieldKey: FieldValue?] = [:]
      for key in Set(original.keys).union(draft.keys) where original[key] != draft[key] {
        changes[key] = draft[key]
      }
      return changes
    }

    public var placeChanged: Bool {
      place.trimmingCharacters(in: .whitespaces) != originalPlace.trimmingCharacters(in: .whitespaces)
    }

    public var canSave: Bool {
      if case .text(let title) = draft[.title] {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      } else {
        false
      }
    }
  }

  public enum Action: ViewAction {
    case saveRefused(ShelfRuleViolation)
    case saveSucceeded
    case view(View)

    public enum View: Equatable {
      case addTapped(String)
      case cancelTapped
      case placeChanged(String)
      case saveTapped
      case valueChanged(FieldKey, FieldValue?)
    }
  }

  @Dependency(\.dismiss) var dismiss
  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .saveRefused(let violation):
        state.refusal = violation
        return .none
      case .saveSucceeded:
        return .run { [dismiss] _ in await dismiss() }
      case .view(.addTapped(let key)):
        state.revealed.insert(key)
        return .none
      case .view(.cancelTapped):
        return .run { [dismiss] _ in await dismiss() }
      case .view(.placeChanged(let place)):
        state.place = place
        state.refusal = nil
        return .none
      case .view(.saveTapped):
        let id = state.id
        let changes = state.changes
        let place = state.placeChanged ? Optional(PlacePath(typed: state.place)) : nil
        return .run { [shelf] send in
          do {
            if !changes.isEmpty { _ = try shelf.perform(.edit(id, values: changes)) }
            if let place { _ = try shelf.perform(.setPlace([id], place)) }
            await send(.saveSucceeded)
          } catch let violation as ShelfRuleViolation {
            await send(.saveRefused(violation))
          } catch {
            reportIssue(error)
          }
        }
      case .view(.valueChanged(let key, let value)):
        state.draft[key] = value
        state.refusal = nil
        return .none
      }
    }
  }
}

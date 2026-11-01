public import ComposableArchitecture
public import Foundation
public import LendFeature
public import ObjectEditFeature
public import ReturnFeature
public import SQLiteData
public import ShareFeature
import TegolaCatalogue
import TegolaClients
public import TegolaModel
public import TegolaStorage

/// One object as a display case (F4, board 04 under PD-013): seven slots in a fixed order (hero, spine, status,
/// signature, fields, actions, history), and controls only as actions: Edit, Photo, Lend or Mark returned, Mark
/// borrowed or Give back, Might let go; Let go joins with its sheet in M8 (D-48).
@Reducer
public struct ObjectFeature {
  /// The sheets the object opens (PLAN §5), one at a time.
  @Reducer
  public enum Destination {
    case edit(ObjectEditFeature)
    case lend(LendFeature)
    case returnLoan(ReturnFeature)
    case share(ShareFeature)
  }

  @ObservableState
  public struct State: Equatable {
    public let id: ObjectID
    @ObservationStateIgnored
    @Fetch public var snapshot: ObjectSnapshot
    @Presents public var destination: Destination.State?
    /// The photo picker is open.
    public var isPickingPhoto = false

    public init(id: ObjectID) {
      self.id = id
      self._snapshot = Fetch(wrappedValue: ObjectSnapshot(), ObjectRequest(id: id))
    }

    public var object: ShelfObject? { snapshot.shelf.shelf.objects[id] }

    /// The object's showing signals now, most urgent first (F15).
    public var signals: [Signal] {
      @Dependency(\.date.now) var now
      return snapshot.shelf.signals(for: id, at: now).sorted { $0.status < $1.status }
    }

    /// The remedies the actions offer, once each (F15, D-58): for a signal that needs attention, and a backup or a
    /// service for a clock that has nothing to read yet, since logging one is what starts it.
    public var remedies: [Signal.Remedy] {
      @Dependency(\.catalogue) var catalogue
      guard let object, object.counts, let type = try? catalogue.resolve(object.typeID, subtype: object.subtype)
      else { return [] }
      let signals = self.signals
      var remedies: [Signal.Remedy] = []
      for clock in type.clocks where !clock.isPending {
        guard let remedy = Signal.remedy(for: clock.name), !remedies.contains(remedy) else { continue }
        let signal = signals.first { $0.clock == clock.name }
        let offered =
          signal.map(\.status.needsAttention)
          ?? (remedy != .batterySwap && object.signalState?.dismissed[clock.name] == nil)
        if offered { remedies.append(remedy) }
      }
      return remedies
    }

    /// The status chip's swatch (D-59).
    public var status: ObjectStatus? {
      @Dependency(\.date.now) var now
      guard let object else { return nil }
      return ObjectStatus.derive(
        object: object,
        signals: signals,
        openLoan: snapshot.shelf.shelf.openLoan(on: id),
        now: now
      )
    }

    /// The History slot: the kinds a person reads, newest first (board 36).
    public var history: [ShelfEvent] {
      snapshot.history.filter(\.kind.readsAsHistory).reversed()
    }

    /// The reducer's own state; the snapshot is the database's (D-47).
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.id == rhs.id && lhs.destination == rhs.destination && lhs.isPickingPhoto == rhs.isPickingPhoto
    }
  }

  public enum Action: ViewAction {
    case destination(PresentationAction<Destination.Action>)
    case view(View)

    public enum View: Equatable {
      case dismissTapped(Signal)
      case editTapped
      case giveBackTapped
      case lendTapped
      case markBorrowedTapped
      case mightLetGoTapped
      case photoPicked(Data)
      case photoPickerDismissed
      case photoTapped
      case remedyTapped(Signal.Remedy)
      case returnTapped
      case shareTapped
    }
  }

  @Dependency(\.calendar) var calendar
  @Dependency(\.date.now) var now
  @Dependency(\.photoStore) var photoStore
  @Dependency(\.shelf) var shelf

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .destination:
        return .none
      case .view(.dismissTapped(let signal)):
        let id = state.id
        return .run { [shelf] _ in
          _ = try shelf.perform(.dismissSignal(id, signal))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.remedyTapped(let remedy)):
        let id = state.id
        return .run { [shelf] _ in
          _ = try shelf.perform(.logEvent(id, kind: remedy.kind, note: ""))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.editTapped):
        guard let object = state.object else { return .none }
        let shelf = state.snapshot.shelf.shelf
        let path = object.placeID.flatMap { shelf.placePath(of: $0) }
        state.destination = .edit(
          ObjectEditFeature.State(object: object, placePath: path, money: state.snapshot.shelf.money)
        )
        return .none
      case .view(.giveBackTapped):
        let id = state.id
        return .run { [shelf] _ in
          _ = try shelf.perform(.giveBack(id))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.lendTapped):
        state.destination = state.lendSheet(.lend, now: now)
        return .none
      case .view(.markBorrowedTapped):
        state.destination = state.lendSheet(.borrow, now: now)
        return .none
      case .view(.returnTapped):
        let shelf = state.snapshot.shelf.shelf
        guard let loan = shelf.openLoan(on: state.id),
          let sheet = ReturnFeature.State(loan: loan.id, shelf: shelf, now: now, calendar: calendar)
        else { return .none }
        state.destination = .returnLoan(sheet)
        return .none
      case .view(.shareTapped):
        state.destination = .share(ShareFeature.State(objectID: state.id))
        return .none
      case .view(.mightLetGoTapped):
        guard let object = state.object else { return .none }
        let id = state.id
        return .run { [shelf] _ in
          _ = try shelf.perform(.setMightLetGo(id, !object.mightLetGo))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.photoPicked(let data)):
        state.isPickingPhoto = false
        let id = state.id
        return .run { [photoStore, shelf, now] _ in
          let fileName = try photoStore.save(data)
          _ = try shelf.perform(.attachPhoto(id, fileName: fileName, takenAt: now))
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.photoPickerDismissed):
        state.isPickingPhoto = false
        return .none
      case .view(.photoTapped):
        state.isPickingPhoto = true
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}

extension ObjectFeature.Destination.State: Equatable {}

extension ObjectFeature.State {
  /// The lend sheet for this object, with the people most recently used first.
  func lendSheet(_ mode: LendFeature.State.Mode, now: Date) -> ObjectFeature.Destination.State? {
    guard let object else { return nil }
    let shelf = snapshot.shelf.shelf
    return .lend(
      LendFeature.State(objectID: id, title: object.title, mode: mode, people: shelf.recentPeople, now: now)
    )
  }
}

public import ComposableArchitecture
public import Foundation
public import SQLiteData
public import TegolaClients
import TegolaCatalogue
public import TegolaModel
public import TegolaStorage

/// The Shelf home (F3, board 01): the count, the Today strip, the collections as tiles, the wishlist, and the empty
/// shelf (board 02) before the first object. It reads the shelf through one query and asks for screens by route.
@Reducer
public struct ShelfFeature {
  @ObservableState
  public struct State: Equatable {
    /// The projection and the money setting, kept current by the database.
    @ObservationStateIgnored
    @Fetch(ShelfRequest()) public var snapshot = ShelfSnapshot()
    /// When the screen last appeared: the Today strip's "now" (overdue is relative to it).
    public var now: Date

    public init(now: Date = .distantPast) {
      self.now = now
    }

    public var summary: ShelfSummary {
      ShelfSummary(
        shelf: snapshot.shelf,
        money: snapshot.money,
        now: now,
        statuses: snapshot.signals(at: now).statuses
      )
    }

    /// Nothing on the shelf at all, wanted objects included: the empty state (board 02).
    public var isEmpty: Bool { snapshot.shelf.objects.isEmpty }

    /// The clock notification offer (F15): once, in plain words, from when the first clocked object arrives until the
    /// collector answers.
    public var offersNotifications: Bool {
      @Dependency(\.catalogue) var catalogue
      guard snapshot.notificationsOffer == nil else { return false }
      return snapshot.shelf.objects.values.contains { object in
        object.counts
          && ((try? catalogue.resolve(object.typeID, subtype: object.subtype))?.clocks
            .contains { !$0.isPending && $0.definition?.isOptIn == false } ?? false)
      }
    }

    /// The clock notifications to schedule now: one for each signal's next change, soonest first, at most 50 (the
    /// system keeps 64 pending).
    public func clockNotifications(at now: Date) -> [LocalNotification] {
      let shelf = snapshot.shelf
      let body = String(localized: "Worth a look: an estimate says it's due.", bundle: .module)
      return snapshot.signals(at: now).signals
        .flatMap { id, signals in
          signals.compactMap { signal -> LocalNotification? in
            guard let at = signal.changesAt, at > now, let object = shelf.objects[id] else { return nil }
            return LocalNotification(
              id: "\(NotificationsClient.clockPrefix)\(id).\(signal.clock)",
              title: object.title,
              body: body,
              at: at
            )
          }
        }
        .sorted { ($0.at, $0.id) < ($1.at, $1.id) }
        .prefix(50)
        .map { $0 }
    }

    /// The reducer's own state. The snapshot is the database's, kept current outside any action, so tests assert on
    /// it directly rather than through exhaustive state comparison.
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.now == rhs.now
    }
  }

  public enum Action: ViewAction {
    case delegate(Delegate)
    case view(View)

    @CasePathable
    public enum Delegate: Equatable {
      /// Add an object by hand (the Scan sheet's Type it).
      case addByHand
      case open(Route)
    }

    public enum View: Equatable {
      case collectionTapped(CollectionID)
      case needAttentionTapped
      case notificationsAccepted
      case notificationsDeclined
      case onAppear
      case placesTapped
      case typeItTapped
    }
  }

  @Dependency(\.date.now) var now
  @Dependency(\.notifications) var notifications
  @Dependency(\.settings) var settings

  public init() {}

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .delegate:
        return .none
      case .view(.collectionTapped(let id)):
        return .send(.delegate(.open(.collection(id))))
      case .view(.needAttentionTapped):
        return .send(.delegate(.open(.signals)))
      case .view(.notificationsAccepted):
        let scheduled = state.clockNotifications(at: now)
        return .run { [notifications, settings] _ in
          try settings.set(.notificationsOffer, "accepted")
          guard try await notifications.requestAuthorization() else { return }
          try await notifications.replaceClockNotifications(scheduled)
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.notificationsDeclined):
        return .run { [settings] _ in
          try settings.set(.notificationsOffer, "declined")
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.onAppear):
        state.now = now
        // Each time the shelf appears, the clock notifications follow the signals: a swap, a dismissal or an edit
        // since last time moves or removes them.
        guard state.snapshot.notificationsOffer == "accepted" else { return .none }
        let scheduled = state.clockNotifications(at: now)
        return .run { [notifications] _ in
          try await notifications.replaceClockNotifications(scheduled)
        } catch: { error, _ in
          reportIssue(error)
        }
      case .view(.placesTapped):
        return .send(.delegate(.open(.places)))
      case .view(.typeItTapped):
        return .send(.delegate(.addByHand))
      }
    }
  }
}

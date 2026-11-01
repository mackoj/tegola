public import Dependencies
import DependenciesMacros
public import Foundation
import Synchronization
public import TegolaModel

#if canImport(UserNotifications)
  import UserNotifications
#endif

/// One local notification: what it says and the day it's for (PLAN §5, F15).
public struct LocalNotification: Hashable, Sendable {
  public let id: String
  public let title: String
  public let body: String
  /// The day it's for. It's delivered that morning, in the collector's calendar.
  public let at: Date

  public init(id: String, title: String, body: String, at: Date) {
    self.id = id
    self.title = title
    self.body = body
    self.at = at
  }
}

/// Local notifications (PLAN §5): the clock notifications (M4) and the loan reminders (M7); the weekly nudge (M8)
/// joins later. Nothing leaves the phone. Each kind is replaced on its own: replacing one never touches the other.
@DependencyClient
public struct NotificationsClient: Sendable {
  /// Asks the system once; true when notifications may be shown.
  public var requestAuthorization: @Sendable () async throws -> Bool
  /// Replaces every pending clock notification with these.
  public var replaceClockNotifications: @Sendable (_ notifications: [LocalNotification]) async throws -> Void
  /// Replaces every pending loan reminder with these (F13: one on each due date). A reminder whose morning has
  /// passed is dropped, never sent late: it was delivered then, or the loan came after it.
  public var replaceLoanReminders: @Sendable (_ notifications: [LocalNotification]) async throws -> Void
  /// Removes a loan's pending reminder, when it comes back before its day.
  public var removeLoanReminder: @Sendable (_ loan: LoanID) async -> Void
}

extension NotificationsClient: DependencyKey {
  /// The prefix every clock notification's id carries, so replacing them leaves other kinds alone.
  public static let clockPrefix = "clock."
  /// The prefix every loan reminder's id carries.
  public static let loanPrefix = "loan."
  /// The hour a notification arrives on its day.
  static let morning = 10

  public static var liveValue: NotificationsClient {
    #if canImport(UserNotifications)
      return NotificationsClient(
        requestAuthorization: {
          try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        },
        replaceClockNotifications: { try await replace(prefix: clockPrefix, with: $0, late: .soon) },
        replaceLoanReminders: { try await replace(prefix: loanPrefix, with: $0, late: .drop) },
        removeLoanReminder: { loan in
          UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [loanID(loan)])
        }
      )
    #else
      return NotificationsClient(
        requestAuthorization: { false },
        replaceClockNotifications: { _ in },
        replaceLoanReminders: { _ in },
        removeLoanReminder: { _ in }
      )
    #endif
  }

  /// A loan reminder's id: the prefix and the loan.
  public static func loanID(_ loan: LoanID) -> String { "\(loanPrefix)\(loan)" }

  /// What happens to a notification whose morning has already passed today.
  enum Late {
    /// A minute from now rather than never: a clock's change is news whenever it's read.
    case soon
    /// Not at all: a loan's reminder was delivered that morning, and rescheduling it would send it again.
    case drop
  }

  #if canImport(UserNotifications)
    /// Removes the pending notifications whose id starts with `prefix`, then schedules these, each on its day's
    /// morning in the collector's calendar.
    static func replace(prefix: String, with notifications: [LocalNotification], late: Late) async throws {
      @Dependency(\.calendar) var calendar
      @Dependency(\.date) var date
      let center = UNUserNotificationCenter.current()
      let pending = await center.pendingNotificationRequests().map(\.identifier)
      center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.hasPrefix(prefix) })
      for notification in notifications {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        var day = calendar.dateComponents([.year, .month, .day], from: notification.at)
        day.hour = morning
        let trigger: UNNotificationTrigger
        if let fire = calendar.date(from: day), fire > date.now {
          trigger = UNCalendarNotificationTrigger(dateMatching: day, repeats: false)
        } else if late == .soon {
          trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        } else {
          continue
        }
        try await center.add(UNNotificationRequest(identifier: notification.id, content: content, trigger: trigger))
      }
    }
  #endif

  public static let testValue = NotificationsClient()

  /// A client that grants permission (or not) and records what's scheduled, for tests and previews.
  public static func recording(granted: Bool = true, into log: NotificationLog) -> NotificationsClient {
    NotificationsClient(
      requestAuthorization: { granted },
      replaceClockNotifications: { notifications in log.record(notifications) },
      replaceLoanReminders: { notifications in log.recordLoans(notifications) },
      removeLoanReminder: { loan in log.recordRemoval(loan) }
    )
  }
}

/// What a recording client scheduled: one entry per replacement, in order.
public final class NotificationLog: Sendable {
  let calls = Mutex<[[LocalNotification]]>([])

  public init() {}

  public var replacements: [[LocalNotification]] { calls.withLock { $0 } }

  func record(_ notifications: [LocalNotification]) { calls.withLock { $0.append(notifications) } }

  let loanCalls = Mutex<[[LocalNotification]]>([])

  /// The loan reminders scheduled, one entry per replacement.
  public var loanReplacements: [[LocalNotification]] { loanCalls.withLock { $0 } }

  func recordLoans(_ notifications: [LocalNotification]) { loanCalls.withLock { $0.append(notifications) } }

  let removals = Mutex<[LoanID]>([])

  /// The loans whose reminder was removed, in order.
  public var removedLoans: [LoanID] { removals.withLock { $0 } }

  func recordRemoval(_ loan: LoanID) { removals.withLock { $0.append(loan) } }
}

extension DependencyValues {
  public var notifications: NotificationsClient {
    get { self[NotificationsClient.self] }
    set { self[NotificationsClient.self] = newValue }
  }
}

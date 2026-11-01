public import Dependencies
import DependenciesMacros
public import Foundation
import Synchronization

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
  /// Replaces every pending loan reminder with these (F13: one on each due date).
  public var replaceLoanReminders: @Sendable (_ notifications: [LocalNotification]) async throws -> Void
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
        replaceClockNotifications: { try await replace(prefix: clockPrefix, with: $0) },
        replaceLoanReminders: { try await replace(prefix: loanPrefix, with: $0) }
      )
    #else
      return NotificationsClient(
        requestAuthorization: { false },
        replaceClockNotifications: { _ in },
        replaceLoanReminders: { _ in }
      )
    #endif
  }

  #if canImport(UserNotifications)
    /// Removes the pending notifications whose id starts with `prefix`, then schedules these, each on its day's
    /// morning in the collector's calendar.
    static func replace(prefix: String, with notifications: [LocalNotification]) async throws {
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
        // Due today, after the morning has passed: a minute from now rather than never.
        let trigger: UNNotificationTrigger =
          if let fire = calendar.date(from: day), fire > date.now {
            UNCalendarNotificationTrigger(dateMatching: day, repeats: false)
          } else {
            UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
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
      replaceLoanReminders: { notifications in log.recordLoans(notifications) }
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
}

extension DependencyValues {
  public var notifications: NotificationsClient {
    get { self[NotificationsClient.self] }
    set { self[NotificationsClient.self] = newValue }
  }
}

public import Dependencies
public import Foundation
public import TegolaModel
public import TegolaStorage

extension ShelfSnapshot {
  /// The shelf's signals and statuses at `now` (F15), with the bundled catalogue and the app's calendar. Every screen
  /// that shows a status reads it from here, so they agree.
  public func signals(at now: Date) -> ShelfSignals {
    @Dependency(\.catalogue) var catalogue
    @Dependency(\.calendar) var calendar
    return ShelfSignals(shelf: shelf, catalogue: catalogue, now: now, calendar: calendar)
  }
}

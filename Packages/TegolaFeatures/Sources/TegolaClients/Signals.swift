public import Dependencies
public import Foundation
import TegolaCatalogue
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

  /// One object's showing signals at `now`, without reading the rest of the shelf.
  public func signals(for id: ObjectID, at now: Date) -> [Signal] {
    @Dependency(\.catalogue) var catalogue
    @Dependency(\.calendar) var calendar
    guard let object = shelf.objects[id], object.counts,
      let type = try? catalogue.resolve(object.typeID, subtype: object.subtype)
    else { return [] }
    return TegolaModel.signals(for: object, type: type, now: now, calendar: calendar)
  }
}

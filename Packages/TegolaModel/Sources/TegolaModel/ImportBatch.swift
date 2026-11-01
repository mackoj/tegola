public import Foundation

/// A list the collector brought, read by an importer and agreed to in one sentence (PLAN F9): what
/// `ShelfCommand.importBatch` writes. Every row lands in one new collection named after the file, unconfirmed
/// (PD-042, PD-047).
public struct ImportBatch: Hashable, Sendable {
  /// Which importer read the file: "tegola-template", "discogs-csv", "spreadsheet".
  public var importer: String
  public var fileName: String
  /// The collection the rows land in; the collector may have renamed it in the sentence.
  public var collectionName: String
  public var rows: [ObjectDraft]

  public init(importer: String, fileName: String, collectionName: String, rows: [ObjectDraft]) {
    self.importer = importer
    self.fileName = fileName
    self.collectionName = collectionName
    self.rows = rows
  }
}

/// An import as the shelf remembers it, so it can be undone for 30 days (PD-047). Its rows carry its id
/// (`ShelfObject.imported`) and its events carry it as their `batchID`.
public struct ImportBatchRecord: Hashable, Sendable, Codable, Identifiable {
  public let id: BatchID
  public let importer: String
  public let fileName: String
  public let collectionID: CollectionID
  public let rowCount: Int
  public let at: Date
  public var undoneAt: Date?

  /// How long an import can be undone (PD-047): thirty days of 24 hours, whatever the calendar does meanwhile.
  public static let undoWindow: TimeInterval = 30 * 24 * 60 * 60

  public func canUndo(at now: Date) -> Bool { undoneAt == nil && now < at + Self.undoWindow }
}

/// Where an imported object came from, and whether the collector has changed it since: an undo removes only what
/// nobody touched (D-12).
public struct ImportMark: Hashable, Sendable, Codable {
  public let batchID: BatchID
  /// Set by the collector's first change after the import: an edit, a photo, a loan, a place, a confirmation.
  /// Lookups and the import itself don't count.
  public var touched: Bool
}

public import Foundation
public import TegolaCatalogue

/// Which importer read a file. A new source is a new importer, not a new pipeline (PLAN F9, Q11).
public struct ImporterID: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(stringLiteral value: String) { self.rawValue = value }
}

/// What the collector brought: CSV, TSV or pasted text, nothing else (49, Q3). A spreadsheet app exports each of its
/// tabs as a file of its own; they arrive together, each with its tab's name ("Vendu", "Recherché").
public struct ImportInput: Sendable {
  public struct Sheet: Sendable {
    public var name: String
    public var data: Data

    public init(name: String, data: Data) {
      self.name = name
      self.data = data
    }
  }

  public var fileName: String
  public var sheets: [Sheet]

  public init(fileName: String, sheets: [Sheet]) {
    self.fileName = fileName
    self.sheets = sheets
  }

  /// One file, one sheet.
  public init(fileName: String, data: Data) {
    self.init(fileName: fileName, sheets: [Sheet(name: fileName, data: data)])
  }

  /// The file's name without its extension or a trailing "collection": the collection's name in the sentence
  /// ("Jeux collection.csv" → "Jeux"), which the collector can change there (49 §06).
  public var collectionName: String {
    var name = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
      .trimmingCharacters(in: .whitespaces)
    for suffix in [" collection", " Collection", " COLLECTION"]
    where name.hasSuffix(suffix) && name.count > suffix.count {
      name = String(name.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
    }
    return name.isEmpty ? fileName : name
  }
}

/// How sure an importer is that a file is its format. The most certain one wins.
public enum Recognition: Hashable, Sendable, Comparable {
  case no
  /// It could read it, for a reason shown under **Something's off** ("one column per platform").
  case likely(reason: String)
  /// Its own header, exactly: nothing will be guessed.
  case certain

  public static func < (lhs: Recognition, rhs: Recognition) -> Bool { lhs.rank < rhs.rank }

  var rank: Int {
    switch self {
    case .no: 0
    case .likely: 1
    case .certain: 2
    }
  }
}

/// One source's reader. It only reads its format into an `ImportPlan`; confirming, writing, matching, the exceptions
/// queue and undo are shared by every importer (PLAN F9).
public protocol Importer: Sendable {
  var id: ImporterID { get }
  func recognises(_ input: ImportInput) -> Recognition
  func plan(_ input: ImportInput, catalogue: Catalogue, extraction: some CellExtracting) async throws -> ImportPlan
}

/// Every importer, asked in turn. The collector can pick another one than the winner under **Something's off**.
public struct ImporterRegistry: Sendable {
  public let importers: [any Importer]

  public init(_ importers: [any Importer]) {
    self.importers = importers
  }

  /// The importers that can read the file, most certain first; on a tie, the registry's order.
  public func candidates(for input: ImportInput) -> [(importer: any Importer, recognition: Recognition)] {
    importers.enumerated()
      .map { (index: $0.offset, importer: $0.element, recognition: $0.element.recognises(input)) }
      .filter { $0.recognition != .no }
      .sorted { ($0.recognition, -$0.index) > ($1.recognition, -$1.index) }
      .map { ($0.importer, $0.recognition) }
  }

  public func best(for input: ImportInput) -> (any Importer)? { candidates(for: input).first?.importer }
}

public enum ImportError: Error, Hashable, Sendable {
  /// Nothing in the file to import.
  case empty
  /// The importer was asked to read a format it doesn't recognise.
  case notThisFormat(ImporterID)
}

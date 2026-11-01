public import TegolaCatalogue
public import TegolaModel

/// One cell to read, with what its column already says: the type, and the subtype or platform the header names.
public struct ImportCell: Hashable, Sendable {
  public var text: String
  public var type: EffectiveType

  public init(text: String, type: EffectiveType) {
    self.text = text
    self.type = type
  }
}

/// A cell read into a typed object (49, "Cell → item"). What wasn't read is in `values[.notes]`, as written.
public struct ExtractedCell: Hashable, Sendable {
  public var title: String
  /// Everything read but the title: parts, grades, signed, a bundle's works, and the note.
  public var values: [FieldKey: FieldValue]
  public var noticed: Set<ImportPlan.Notice>

  public init(
    title: String,
    values: [FieldKey: FieldValue] = [:],
    noticed: Set<ImportPlan.Notice> = []
  ) {
    self.title = title
    self.values = values
    self.noticed = noticed
  }

  /// A bundle's works, from the item level's `contains`.
  public var works: [String] {
    guard case .entries(let entries) = values[.field("contains")] else { return [] }
    return entries.compactMap { $0["work"] }
  }
}

/// Reads cells into typed objects. On a phone with Apple Intelligence, Foundation Models' guided generation does it
/// (`ExtractionClient`, T6.10), 20–30 cells a call; `NoteReader` is the rule-based reader used without it, and the
/// one the tests pin. Either must never invent a value: anything it can't read goes into the note, untouched.
public protocol CellExtracting: Sendable {
  func extract(_ cells: [ImportCell]) async throws -> [ExtractedCell]
}

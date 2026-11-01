public import TegolaCatalogue
public import TegolaModel

/// What an importer understood, before anything is written: the one sentence to confirm, the rows, what was guessed
/// and what was noticed (PLAN F9). Every importer produces one; `batch()` is what **Build my shelf** sends.
public struct ImportPlan: Hashable, Sendable {
  /// Something the collector's own notes said, for the payoff (49 §05) and the saved views (F11).
  public enum Notice: String, Hashable, Sendable, CaseIterable {
    /// A part damaged, not working or missing.
    case imperfect
    /// A second copy ("doublon").
    case duplicate
    case signed
    /// Two or more works in one object ("Heavy rain / beyond 2 souls").
    case bundle
    /// Not a physical copy ("It take two (digital)").
    case digital
  }

  /// A row the exceptions queue asks about, one tap each, never a gate: **Keep as I wrote it** is the default
  /// (49 §04). Variants come later, from matching.
  public enum Question: Hashable, Sendable {
    /// One object holding these works, or several objects?
    case bundle(works: [String])
    /// A digital copy: keep it, move it to the wishlist, or leave it out (43 Q4)?
    case digital
  }

  public struct Row: Hashable, Sendable {
    public var draft: ObjectDraft
    /// The cell or line as the collector wrote it: "YOU WROTE" in the exceptions queue.
    public var written: String
    /// Where it came from: the sheet, and the line in it (1-based, the header included).
    public var sheet: String
    public var line: Int
    /// The shelf inside the collection: the platform or medium the row sits under (49 §06).
    public var shelf: String?
    public var noticed: Set<Notice>
    public var question: Question?

    public init(
      draft: ObjectDraft,
      written: String,
      sheet: String,
      line: Int,
      shelf: String? = nil,
      noticed: Set<Notice> = [],
      question: Question? = nil
    ) {
      self.draft = draft
      self.written = written
      self.sheet = sheet
      self.line = line
      self.shelf = shelf
      self.noticed = noticed
      self.question = question
    }
  }

  /// Something read as something else, shown as a dashed chip in the sentence: "Game Boy advence" → GBA (49 §02).
  public struct Guess: Hashable, Sendable {
    public var written: String
    public var readAs: String

    public init(written: String, readAs: String) {
      self.written = written
      self.readAs = readAs
    }
  }

  public var importer: ImporterID
  public var fileName: String
  /// The collection the rows land in. The sentence offers to rename it.
  public var collectionName: String
  public var rows: [Row]
  public var guessed: [Guess]

  public init(importer: ImporterID, fileName: String, collectionName: String, rows: [Row], guessed: [Guess] = []) {
    self.importer = importer
    self.fileName = fileName
    self.collectionName = collectionName
    self.rows = rows
    self.guessed = guessed
  }

  /// The types the rows are, most rows first: the sentence's "video games".
  public var types: [TypeManifest.ID] {
    let counts = Dictionary(grouping: rows, by: \.draft.type).mapValues(\.count)
    return counts.keys.sorted { (counts[$0]!, $1.rawValue) > (counts[$1]!, $0.rawValue) }
  }

  /// The shelves, in the order the file first names them: the sentence's "on 20 platforms".
  public var shelves: [String] {
    var seen: Set<String> = []
    return rows.compactMap(\.shelf).filter { seen.insert($0).inserted }
  }

  public func count(_ notice: Notice) -> Int { rows.filter { $0.noticed.contains(notice) }.count }

  /// The rows the exceptions queue holds.
  public var toSort: [Row] { rows.filter { $0.question != nil } }

  /// What **Build my shelf** sends: every row, in the file's order, into the collection as named now.
  public func batch() -> ImportBatch {
    ImportBatch(
      importer: importer.rawValue,
      fileName: fileName,
      collectionName: collectionName,
      rows: rows.map(\.draft)
    )
  }
}

import Foundation
public import TegolaCatalogue
import TegolaModel

/// Any CSV, TSV or pasted text that isn't a known export (PLAN F9). Two layouts:
///
/// - **A grid**, a column per platform or format with no title header, as `Jeux collection.csv` is: each header
///   that names a subtype exactly becomes it, any other header is the platform as written, and every cell is an
///   object (49 §06).
/// - **A list**, a row per object under headers: the headers map to the spine and the type's fields (clctn's
///   aliases, English and French), and a column nothing maps goes into the note, "Header: value".
///
/// Each title cell goes through the cell reader, so notes in brackets are read in both layouts. A sheet named like a
/// wishlist ("Recherché", "Wanted") is wanted objects, not a collection (49 §06).
public struct SpreadsheetImporter: Importer {
  public let id: ImporterID = "spreadsheet"

  public init() {}

  public func recognises(_ input: ImportInput) -> Recognition {
    let tables = input.sheets.compactMap { try? DelimitedText(data: $0.data) }
    guard tables.contains(where: { !$0.rows.isEmpty }) else { return .no }
    return .likely(reason: "rows of text")
  }

  public func plan(_ input: ImportInput, catalogue: Catalogue, extraction: some CellExtracting) async throws
    -> ImportPlan
  {
    var rows: [ImportPlan.Row] = []
    var guessed: [ImportPlan.Guess] = []
    for sheet in input.sheets {
      let table = try DelimitedText(data: sheet.data)
      let ownership: ShelfObject.Ownership = Self.isWishlist(sheet.name) ? .wanted : .owned
      if let grid = Grid(table, catalogue: catalogue) {
        guessed += grid.guessed
        rows += try await grid.rows(
          sheet: sheet.name,
          ownership: ownership,
          catalogue: catalogue,
          extraction: extraction
        )
      } else {
        let list = List(table, fileName: input.fileName, catalogue: catalogue)
        rows += try await list.rows(
          sheet: sheet.name,
          ownership: ownership,
          catalogue: catalogue,
          extraction: extraction
        )
      }
    }
    guard !rows.isEmpty else { throw ImportError.empty }
    var seen: Set<ImportPlan.Guess> = []
    return ImportPlan(
      importer: id,
      fileName: input.fileName,
      collectionName: input.collectionName,
      rows: rows,
      guessed: guessed.filter { seen.insert($0).inserted }
    )
  }

  static let wishlistNames = ["recherche", "recherches", "wanted", "wishlist", "envies", "a acheter", "liste d'envies"]

  static func isWishlist(_ name: String) -> Bool {
    let stem = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
    return wishlistNames.contains(Parts.fold(stem).trimmingCharacters(in: .whitespaces))
  }
}

/// A sheet whose headers name a type's subtypes: Ps1, N64, Game Boy, Sega Saturn.
struct Grid {
  struct Column {
    let index: Int
    let header: String
    let subtype: TypeManifest.Subtype?
  }

  let table: DelimitedText
  let type: TypeManifest
  let columns: [Column]

  /// A grid needs two headers that each name one subtype of the same type, exactly: "Game Boy advence" isn't Game
  /// Boy. Nil when no type has two.
  init?(_ table: DelimitedText, catalogue: Catalogue) {
    let headers = table.header
    let best = catalogue.manifests.filter { Catalogue.enabledInV1.contains($0.id) }.map { manifest in
      (manifest, headers.map { Self.subtype(named: $0, in: manifest) })
    }
    .max { $0.1.count { $0 != nil } < $1.1.count { $0 != nil } }
    guard let (manifest, subtypes) = best, subtypes.count(where: { $0 != nil }) >= 2 else { return nil }
    self.table = table
    self.type = manifest
    self.columns = headers.indices.map { Column(index: $0, header: headers[$0], subtype: subtypes[$0]) }
  }

  static func subtype(named header: String, in manifest: TypeManifest) -> TypeManifest.Subtype? {
    let words = Self.words(header)
    guard !words.isEmpty else { return nil }
    let matches = manifest.subtypes.filter { subtype in
      ([subtype.key, subtype.label] + subtype.recognise).contains { Self.words($0) == words }
    }
    return matches.count == 1 ? matches[0] : nil
  }

  static func words(_ text: String) -> [String] {
    Parts.fold(text).split { !$0.isLetter && !$0.isNumber }.map(String.init)
  }

  /// Headers read as a subtype whose name the file spells differently: the sentence's dashed chips.
  var guessed: [ImportPlan.Guess] {
    columns.compactMap { column in
      guard let subtype = column.subtype, column.header != subtype.label else { return nil }
      return ImportPlan.Guess(written: column.header, readAs: subtype.label)
    }
  }

  /// The field every subtype presets with its own name (video games' platform): where a header that names no
  /// subtype goes, as written.
  var platformField: String? {
    type.fields.first { field in
      field.kind == .text && !type.subtypes.isEmpty && type.subtypes.allSatisfy { $0.presets[field.key] != nil }
    }?.key
  }

  func rows(
    sheet: String,
    ownership: ShelfObject.Ownership,
    catalogue: Catalogue,
    extraction: some CellExtracting
  ) async throws -> [ImportPlan.Row] {
    var cells: [(line: Int, column: Column, cell: ImportCell)] = []
    for (offset, row) in table.body.enumerated() {
      for column in columns where column.index < row.count && !row[column.index].isEmpty {
        let effective = try catalogue.resolve(type.id, subtype: column.subtype?.key)
        cells.append((offset + 2, column, ImportCell(text: row[column.index], type: effective)))
      }
    }
    let read = try await extraction.extract(cells.map(\.cell))
    return zip(cells, read).map { entry, extracted in
      var values: [FieldKey: FieldValue] = [:]
      if entry.column.subtype == nil, !entry.column.header.isEmpty, let platform = platformField {
        values[.field(platform)] = .text(entry.column.header)
      }
      return RowBuilder(catalogue: catalogue).rows(
        extracted,
        written: entry.cell.text,
        type: entry.cell.type,
        values: values,
        ownership: ownership,
        sheet: sheet,
        line: entry.line,
        shelf: entry.column.subtype?.label ?? (entry.column.header.isEmpty ? nil : entry.column.header)
      )
    }
  }
}

/// A sheet with a row per object under headers.
struct List {
  enum Destination: Hashable {
    case title, subtitle, year, notes
    case field(String)
    /// Kept in the note as "Header: value".
    case note
  }

  let table: DelimitedText
  let type: TypeManifest.ID
  let destinations: [Destination]
  let titleColumn: Int

  /// The headers a spine slot answers to, in English and French (clctn's `ColumnMapping.spineAliases`), squashed.
  static let aliases: [Destination: Set<String>] = [
    .title: ["title", "name", "album", "titre", "nom", "item", "object", "objet", "work", "jeu", "game"],
    .subtitle: [
      "artist", "author", "subtitle", "artiste", "auteur", "creator", "maker", "by", "band", "platform",
      "plateforme", "console",
    ],
    .year: ["year", "released", "releaseyear", "annee", "date", "yearofrelease", "sortie"],
    .notes: ["notes", "note", "comment", "comments", "remarks", "commentaire", "commentaires", "remarques"],
  ]

  /// "Catalog #", "catalog_number" and "catalogNumber" are one column.
  static func squash(_ header: String) -> String { Parts.fold(header).filter { $0.isLetter || $0.isNumber } }

  init(_ table: DelimitedText, fileName: String, catalogue: Catalogue) {
    self.table = table
    // The type the file's name and headers name, if it ships; otherwise a Thing (D-62).
    let guess = catalogue.guess(from: ([fileName] + table.header).joined(separator: " "))
    let type: TypeManifest.ID = guess.flatMap { $0.isEnabled ? $0.type : nil } ?? "thing"
    self.type = type
    let fields = catalogue.manifest(type)?.fields ?? []
    var used: Set<Destination> = []
    var destinations: [Destination] = []
    for header in table.header {
      let squashed = Self.squash(header)
      var destination: Destination = .note
      if let spine = [Destination.title, .subtitle, .year, .notes].first(where: { Self.aliases[$0]!.contains(squashed) }
      ),
        spine == .notes || !used.contains(spine)
      {
        destination = spine
      } else if let field = fields.first(where: { Self.squash($0.key) == squashed || Self.squash($0.label) == squashed }
      ),
        [.text, .choice].contains(field.kind)
      {
        destination = .field(field.key)
      }
      used.insert(destination)
      destinations.append(destination)
    }
    self.destinations = destinations
    // Without a title header, the first column is the name: only "name" is required (PD-048).
    self.titleColumn = destinations.firstIndex(of: .title) ?? 0
  }

  func rows(
    sheet: String,
    ownership: ShelfObject.Ownership,
    catalogue: Catalogue,
    extraction: some CellExtracting
  ) async throws -> [ImportPlan.Row] {
    let effective = try catalogue.resolve(type, subtype: nil)
    let hasTitleHeader = destinations.contains(.title)
    let body = hasTitleHeader ? Array(table.body) : Array(table.rows)
    let firstLine = hasTitleHeader ? 2 : 1
    let lines = body.enumerated().filter { _, row in titleColumn < row.count && !row[titleColumn].isEmpty }
    let read = try await extraction.extract(lines.map { ImportCell(text: $0.element[titleColumn], type: effective) })
    return zip(lines, read).map { line, extracted in
      let (offset, row) = line
      var values: [FieldKey: FieldValue] = [:]
      var notes: [String] = []
      for (index, cell) in row.enumerated() where index != titleColumn && !cell.isEmpty {
        let header = index < table.header.count && hasTitleHeader ? table.header[index] : ""
        switch index < destinations.count && hasTitleHeader ? destinations[index] : .note {
        case .subtitle: values[.subtitle] = .text(cell)
        case .year:
          if let year = Int(cell.trimmingCharacters(in: .whitespaces)), (1000...9999).contains(year) {
            values[.year] = .year(year)
          } else {
            notes.append("\(header): \(cell)")
          }
        case .field(let key):
          let field = effective.field(key)?.field
          if field?.kind == .text || field?.options.contains(cell) == true {
            values[.field(key)] = .text(cell)
          } else {
            notes.append("\(header): \(cell)")
          }
        case .notes: notes.append(cell)
        case .title, .note: notes.append(header.isEmpty ? cell : "\(header): \(cell)")
        }
      }
      if !notes.isEmpty { values[.notes] = .text(notes.joined(separator: "\n")) }
      return RowBuilder(catalogue: catalogue).rows(
        extracted,
        written: row.joined(separator: " · "),
        type: effective,
        values: values,
        ownership: ownership,
        sheet: sheet,
        line: offset + firstLine,
        shelf: nil
      )
    }
  }
}

import Foundation
public import TegolaCatalogue
import TegolaModel

/// The CSV Discogs exports from a collection (Collection → Export): one release per row, into Music, with the medium
/// as the subtype (PLAN F9). Discogs grades on the Goldmine scale, which is Music's, so its grades map directly; a
/// grade Music doesn't have ("G+") and every column with no field stay in the note (D-68).
public struct DiscogsCSVImporter: Importer {
  public let id: ImporterID = "discogs-csv"

  public init() {}

  /// The columns every Discogs collection export starts with.
  static let signature: Set<String> = ["Catalog#", "Artist", "Title", "Label", "Format", "release_id"]

  public func recognises(_ input: ImportInput) -> Recognition {
    let headers = input.sheets.compactMap { try? DelimitedText(data: $0.data).header }
    guard !headers.isEmpty, headers.allSatisfy({ Self.signature.isSubset(of: $0) }) else { return .no }
    return .certain
  }

  public func plan(_ input: ImportInput, catalogue: Catalogue, extraction: some CellExtracting) async throws
    -> ImportPlan
  {
    var rows: [ImportPlan.Row] = []
    for sheet in input.sheets {
      let table = try DelimitedText(data: sheet.data)
      guard Self.signature.isSubset(of: table.header) else { throw ImportError.notThisFormat(id) }
      for (offset, cells) in table.body.enumerated() {
        let row = Dictionary(zip(table.header, cells).filter { !$1.isEmpty }, uniquingKeysWith: { first, _ in first })
        guard row["Title"] != nil else { continue }
        rows.append(
          try read(
            row,
            order: table.header,
            written: cells.joined(separator: ","),
            sheet: sheet.name,
            line: offset + 2,
            catalogue
          )
        )
      }
    }
    guard !rows.isEmpty else { throw ImportError.empty }
    return ImportPlan(importer: id, fileName: input.fileName, collectionName: input.collectionName, rows: rows)
  }

  func read(
    _ row: [String: String],
    order: [String],
    written: String,
    sheet: String,
    line: Int,
    _ catalogue: Catalogue
  ) throws -> ImportPlan.Row {
    let format = row["Format"].map(Self.format) ?? (subtype: nil, format: nil, rest: [])
    let type = try catalogue.resolve("music", subtype: format.subtype)
    var values: [FieldKey: FieldValue] = [:]
    var notes: [String] = []
    if let artist = row["Artist"] { values[.subtitle] = .text(Self.artist(artist)) }
    if let year = row["Released"], let number = Int(year), number > 0 { values[.year] = .year(number) }
    if let label = row["Label"] { values[.field("label")] = .text(label) }
    if let number = row["Catalog#"], number != "none" { values[.field("catalogNumber")] = .text(number) }
    if let chosen = format.format, type.field("format")?.field.options.contains(chosen) == true {
      values[.field("format")] = .text(chosen)
    }
    if !format.rest.isEmpty { notes.append("Format: \(format.rest.joined(separator: ", "))") }
    if let grade = row["Collection Media Condition"] {
      if let step = Self.grade(grade), type.conditions.contains(step) {
        values[.condition] = .text(step)
      } else {
        notes.append("Media: \(grade)")
      }
    }
    if let grade = row["Collection Sleeve Condition"] {
      let step = grade == "No Cover" ? "Missing" : Self.grade(grade)
      if let step, type.field("packagingCondition")?.field.options.contains(step) == true {
        values[.field("packagingCondition")] = .text(step)
      } else {
        notes.append("Sleeve: \(grade)")
      }
    }
    if let folder = row["CollectionFolder"], folder != "Uncategorized" { notes.append("Folder: \(folder)") }
    if let rating = row["Rating"], rating != "0" { notes.append("Rating: \(rating)") }
    if let id = row["release_id"] { notes.append("Discogs release: \(id)") }
    if let added = row["Date Added"] { notes.append("Added to Discogs: \(added)") }
    if let note = row["Collection Notes"] { notes.insert(note, at: 0) }
    // Custom collection fields, after Discogs' own columns.
    for header in order where !Self.known.contains(header) {
      if let value = row[header] { notes.append("\(header): \(value)") }
    }
    if !notes.isEmpty { values[.notes] = .text(notes.joined(separator: "\n")) }
    let extracted = ExtractedCell(title: row["Title"] ?? written, values: values)
    return RowBuilder(catalogue: catalogue).rows(
      extracted,
      written: written,
      type: type,
      values: [:],
      ownership: .owned,
      sheet: sheet,
      line: line,
      shelf: format.subtype.flatMap { key in catalogue.manifest("music")?.subtypes.first { $0.key == key }?.label }
    )
  }

  static let known: Set<String> = signature.union([
    "Rating", "Released", "CollectionFolder", "Date Added", "Collection Media Condition",
    "Collection Sleeve Condition", "Collection Notes",
  ])

  /// "Nirvana (2)" is Discogs telling two Nirvanas apart, not the artist's name.
  static func artist(_ name: String) -> String {
    name.replacingOccurrences(of: #"\s\(\d+\)$"#, with: "", options: .regularExpression)
  }

  /// "Very Good Plus (VG+)" → "VG+", on Music's scale's own words.
  static func grade(_ discogs: String) -> String? {
    switch discogs.split(separator: "(").first?.trimmingCharacters(in: .whitespaces) {
    case "Mint": "Mint"
    case "Near Mint": "Near Mint"
    case "Very Good Plus": "VG+"
    case "Very Good": "VG"
    case "Good": "Good"
    case "Fair": "Fair"
    case "Poor": "Poor"
    default: nil
    }
  }

  /// Discogs' format, "2xLP, Album, RE": the medium's subtype, the format Music names, and the descriptions left.
  static func format(_ text: String) -> (subtype: String?, format: String?, rest: [String]) {
    var parts = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    guard let first = parts.first else { return (nil, nil, []) }
    let count = first.firstMatch(of: /^(\d+)x/).flatMap { Int($0.1) }
    let name = count == nil ? first : String(first.drop { $0 != "x" }.dropFirst())
    let read: (subtype: String, format: String)? =
      switch name {
      case "LP": ("vinyl", count.map { "\($0)×LP" } ?? "LP")
      case "Vinyl": ("vinyl", "")
      case "7\"", "10\"", "12\"": ("vinyl", count == nil ? name : "")
      case "CD": ("cd", count.map { "\($0)×CD" } ?? "CD")
      case "CDr": ("cd", "")
      case "Cass", "Cassette": ("cassette", count.map { "\($0)×Cassette" } ?? "Cassette")
      case "Minidisc": ("other", "MiniDisc")
      case "Reel-To-Reel": ("other", "Reel-to-reel")
      case "8-Track Cartridge": ("other", "8-track")
      case "DAT": ("other", "DAT")
      default: nil
      }
    guard let read else { return (nil, nil, parts) }
    parts.removeFirst()
    if read.format.isEmpty { parts.insert(first, at: 0) }
    return (read.subtype, read.format.isEmpty ? nil : read.format, parts)
  }
}

import Foundation
public import TegolaCatalogue
import TegolaModel

/// The published `tegola.csv` template, which Export writes too: one row per object, fixed headers, comma-separated
/// UTF-8 (49 §03B). A file with its header imports with nothing guessed, and nothing goes through the cell reader.
public enum TemplateFormat {
  /// Every template has these, in this order, before the type's own fields. `type` and `title` are the only ones a
  /// row must fill.
  public static let columns = [
    "type", "subtype", "title", "subtitle", "year", "parts", "condition", "signed_by", "contains", "note",
  ]

  /// A list cell's separator: "box|cart", "Doom|Doom 2".
  public static let listSeparator: Character = "|"
}

/// Reads the template. Any header after the fixed columns is a field key of a type ("region", "catalogNumber"), so
/// Export can write every field without the template changing (D-63).
public struct TemplateImporter: Importer {
  public let id: ImporterID = "tegola-template"

  public init() {}

  public func recognises(_ input: ImportInput) -> Recognition {
    let headers = input.sheets.compactMap { try? DelimitedText(data: $0.data).header }
    guard !headers.isEmpty, headers.allSatisfy(Self.isTemplate) else { return .no }
    return .certain
  }

  /// The fixed columns first, in order, with `type` and `title` among them.
  static func isTemplate(_ header: [String]) -> Bool {
    let fixed = header.prefix(while: TemplateFormat.columns.contains)
    return fixed.contains("type") && fixed.contains("title")
      && Array(fixed) == TemplateFormat.columns.filter(fixed.contains)
  }

  public func plan(_ input: ImportInput, catalogue: Catalogue, extraction: some CellExtracting) async throws
    -> ImportPlan
  {
    var rows: [ImportPlan.Row] = []
    for sheet in input.sheets {
      let table = try DelimitedText(data: sheet.data)
      guard Self.isTemplate(table.header) else { throw ImportError.notThisFormat(id) }
      for (offset, cells) in table.body.enumerated() {
        let row = Dictionary(
          zip(table.header, cells).filter { !$1.isEmpty },
          uniquingKeysWith: { first, _ in first }
        )
        guard row["title"] != nil || row["type"] != nil else { continue }
        rows.append(read(row, written: cells.joined(separator: ","), sheet: sheet.name, line: offset + 2, catalogue))
      }
    }
    guard !rows.isEmpty else { throw ImportError.empty }
    return ImportPlan(importer: id, fileName: input.fileName, collectionName: input.collectionName, rows: rows)
  }

  func read(_ row: [String: String], written: String, sheet: String, line: Int, _ catalogue: Catalogue)
    -> ImportPlan.Row
  {
    var notes: [String] = []
    let typeID = TypeManifest.ID(rawValue: row["type"] ?? "")
    let manifest = catalogue.manifest(typeID)
    let subtype = row["subtype"].flatMap { key in manifest?.subtypes.contains { $0.key == key } == true ? key : nil }
    if let written = row["subtype"], subtype == nil { notes.append("subtype: \(written)") }
    // A type the app doesn't know is a Thing with the type in its note; one that hasn't shipped is a Thing waiting
    // for it (D-59). Either keeps every cell.
    guard let manifest, Catalogue.enabledInV1.contains(manifest.id),
      let type = try? catalogue.resolve(manifest.id, subtype: subtype)
    else {
      if manifest == nil { notes.append("type: \(typeID.rawValue)") }
      return fallback(row, notes: notes, written: written, sheet: sheet, line: line, awaiting: manifest?.id)
    }
    var values: [FieldKey: FieldValue] = [:]
    if let title = row["title"] { values[.title] = .text(title) }
    if let subtitle = row["subtitle"] { values[.subtitle] = .text(subtitle) }
    if let year = row["year"] {
      if let year = Int(year) { values[.year] = .year(year) } else { notes.append("year: \(year)") }
    }
    let parts = Parts(type: type)
    if let written = row["parts"] {
      let slots = Self.list(written)
      if let field = parts.slotField, Set(slots).isSubset(of: field.field.options) {
        values[.field(field.key)] = .options(slots)
      } else {
        notes.append("parts: \(written)")
      }
    }
    if let written = row["condition"] {
      for grade in Self.list(written) {
        if let (key, value) = Self.condition(grade, type: type) { values[key] = value } else { notes.append(grade) }
      }
    }
    if let names = row["signed_by"], type.field("signed") != nil {
      values[.field("signed")] = .entries(Self.list(names).map { ["by": $0] })
    }
    if let works = row["contains"], type.field("contains") != nil {
      values[.field("contains")] = .entries(Self.list(works).map { ["work": $0] })
    }
    for (header, text) in row where !TemplateFormat.columns.contains(header) {
      if let field = type.field(header), !field.isHidden, let value = FieldReading.value(text, for: field.field) {
        values[.field(header)] = value
      } else {
        notes.append("\(header): \(text)")
      }
    }
    if let note = row["note"] { notes.insert(note, at: 0) }
    if !notes.isEmpty { values[.notes] = .text(notes.joined(separator: "\n")) }
    let draft = ObjectDraft(type: manifest.id, subtype: subtype, values: values)
    guard values[.title] != nil, RowBuilder(catalogue: catalogue).accepts(draft) else {
      return fallback(row, notes: notes, written: written, sheet: sheet, line: line, awaiting: nil)
    }
    let shelf = subtype.flatMap { key in manifest.subtypes.first { $0.key == key }?.label }
    return ImportPlan.Row(draft: draft, written: written, sheet: sheet, line: line, shelf: shelf)
  }

  /// The row as a Thing: its title (or the row as written), and every other cell in the note.
  func fallback(
    _ row: [String: String],
    notes: [String],
    written: String,
    sheet: String,
    line: Int,
    awaiting: TypeManifest.ID?
  ) -> ImportPlan.Row {
    let rest = row.filter { $0.key != "title" && $0.key != "type" && $0.key != "note" }.sorted { $0.key < $1.key }
    let note = ([row["note"]].compactMap { $0 } + notes + rest.map { "\($0.key): \($0.value)" }).uniqued()
    var values: [FieldKey: FieldValue] = [.title: .text(row["title"] ?? written)]
    if !note.isEmpty { values[.notes] = .text(note.joined(separator: "\n")) }
    let draft = ObjectDraft(type: "thing", values: values, awaitingType: awaiting)
    return ImportPlan.Row(draft: draft, written: written, sheet: sheet, line: line)
  }

  static func list(_ text: String) -> [String] {
    text.split(separator: TemplateFormat.listSeparator).map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  /// "Near mint" is the object's condition; "boxCondition:Poor" grades a ladder axis.
  static func condition(_ text: String, type: EffectiveType) -> (FieldKey, FieldValue)? {
    let pair = text.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
    if pair.count == 2 {
      guard let axis = type.field(pair[0]), axis.field.ladderAxis != nil, type.ladderSteps.contains(pair[1]) else {
        return nil
      }
      return (.axis(axis.key), .text(pair[1]))
    }
    return type.conditions.contains(text) ? (.condition, .text(text)) : nil
  }
}

/// A field's value from the text a file holds, when it fits the field's kind and options; nil otherwise, and the
/// text goes into the note.
enum FieldReading {
  static func value(_ text: String, for field: TypeManifest.Field) -> FieldValue? {
    switch field.kind {
    case .text, .dims: return .text(text)
    case .choice: return field.options.isEmpty || field.options.contains(text) ? .text(text) : nil
    case .number: return Double(text.replacingOccurrences(of: ",", with: ".")).map(FieldValue.number)
    case .year: return Int(text).map(FieldValue.year)
    case .yesNo:
      switch Parts.fold(text) {
      case "yes", "true", "oui", "vrai", "1": return .flag(true)
      case "no", "false", "non", "faux", "0": return .flag(false)
      default: return nil
      }
    case .set:
      let options = TemplateImporter.list(text)
      return field.options.isEmpty || Set(options).isSubset(of: field.options) ? .options(options) : nil
    default: return nil
    }
  }
}

extension Array where Element: Hashable {
  func uniqued() -> [Element] {
    var seen: Set<Element> = []
    return filter { seen.insert($0).inserted }
  }
}

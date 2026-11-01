public import Foundation
public import TegolaCatalogue
public import TegolaModel

/// Export (F17, D-81): the shelf as the `tegola.csv` template, which Bring your list reads back, and as JSON, which
/// keeps everything.
///
/// - **CSV**, in the template's shape (T6.3): one row per object on the shelf (let-go objects stay in the archive and
///   the JSON), the fixed columns and then every type field the rows use, by key. Importing it gives back the same
///   objects with the same values. A value the template can't carry (a date, a log) goes into the note as
///   `key: value`, as the importer does with a cell it can't read. Money never goes in: a note shows with money off
///   (promise 5), so paid and value stay in the JSON.
/// - **JSON**: the whole projection (objects, collections, places, people, loans, photos' file names), versioned.
///   Photos travel beside it as files.
public enum ShelfExport {
  /// The JSON document's format name and version.
  public static let format = "tegola-shelf"
  public static let version = 1

  /// The JSON document: the shelf as it is, dated.
  public struct Document: Codable, Hashable, Sendable {
    public let format: String
    public let version: Int
    public let exportedAt: Date
    public let shelf: Shelf

    public init(shelf: Shelf, exportedAt: Date) {
      self.format = ShelfExport.format
      self.version = ShelfExport.version
      self.exportedAt = exportedAt
      self.shelf = shelf
    }
  }

  public static func json(_ shelf: Shelf, exportedAt: Date) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(Document(shelf: shelf, exportedAt: exportedAt))
  }

  public static func document(from data: Data) throws -> Document {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Document.self, from: data)
  }

  /// The objects the CSV holds: on the shelf, not let go, in a stable order (type, then title).
  public static func exported(_ shelf: Shelf) -> [ShelfObject] {
    shelf.objects.values.filter { $0.letGo == nil }
      .sorted { ($0.typeID.rawValue, $0.title, $0.id) < ($1.typeID.rawValue, $1.title, $1.id) }
  }

  /// The shelf as the template.
  public static func csv(_ shelf: Shelf, catalogue: Catalogue) -> String {
    let rows = exported(shelf).map { row($0, catalogue: catalogue) }
    // Every type field any row uses, in the order its type lists it, first seen first.
    var fields: [String] = []
    for object in exported(shelf) {
      guard let type = try? catalogue.resolve(object.typeID, subtype: object.subtype) else { continue }
      for field in type.fields where !fields.contains(field.key) && rows.contains(where: { $0[field.key] != nil }) {
        fields.append(field.key)
      }
    }
    let header = TemplateFormat.columns + fields
    let lines = [header] + rows.map { row in header.map { row[$0] ?? "" } }
    return lines.map { $0.map(Self.cell).joined(separator: ",") }.joined(separator: "\n") + "\n"
  }

  /// One object as the template's cells, by header.
  static func row(_ object: ShelfObject, catalogue: Catalogue) -> [String: String] {
    var row: [String: String] = ["type": object.typeID.rawValue, "title": object.title]
    var notes: [String] = []
    if case .text(let note) = object.values[.notes] { notes.append(note) }
    if let subtype = object.subtype { row["subtype"] = subtype }
    if case .text(let subtitle) = object.values[.subtitle] { row["subtitle"] = subtitle }
    if case .year(let year) = object.values[.year] { row["year"] = String(year) }
    guard let type = try? catalogue.resolve(object.typeID, subtype: object.subtype) else {
      row["note"] = notes.joined(separator: "\n")
      return row
    }
    let slotField = Parts(type: type).slotField?.key
    let ladder = Set(type.signatures.flatMap(\.axes))
    var grades: [String] = []
    if case .text(let condition) = object.values[.condition] { grades.append(condition) }
    for axis in type.signatures.flatMap(\.axes) {
      if case .text(let grade) = object.values[.axis(axis)] { grades.append("\(axis):\(grade)") }
    }
    if !grades.isEmpty { row["condition"] = grades.joined(separator: "|") }
    for (key, value) in object.values.sorted(by: { $0.key < $1.key }) {
      // Promise 5: no money in a file that becomes notes again.
      if case .money = value { continue }
      guard case .field(let name) = key else {
        // Acquired isn't a template column: it goes in the note.
        if key == .acquired, let text = text(value) { notes.append("\(key): \(text)") }
        continue
      }
      // A subtype's preset (a Saturn's platform, a vinyl's medium) comes back with the subtype: nothing to write.
      if let field = type.field(name), field.isHidden, field.presetValue != nil { continue }
      if name == slotField, case .options(let slots) = value {
        row["parts"] = slots.joined(separator: "|")
      } else if name == "signed", case .entries(let entries) = value {
        row["signed_by"] = entries.compactMap { $0["by"] }.joined(separator: "|")
      } else if name == "contains", case .entries(let entries) = value {
        row["contains"] = entries.compactMap { $0["work"] }.joined(separator: "|")
      } else if !ladder.contains(name), let field = type.field(name), !field.isHidden,
        let cell = cell(value, kind: field.field.kind)
      {
        row[name] = cell
      } else if let text = text(value) {
        notes.append("\(name): \(text)")
      }
    }
    if !notes.isEmpty { row["note"] = notes.joined(separator: "\n") }
    return row
  }

  /// A value as the importer reads it back for a field of this kind; nil when the template can't carry it.
  static func cell(_ value: FieldValue, kind: FieldKind) -> String? {
    switch (value, kind) {
    case (.text(let text), .text), (.text(let text), .dims), (.text(let text), .choice): text
    case (.number(let number), .number): number.formatted(.number.grouping(.never).locale(Locale(identifier: "en")))
    case (.year(let year), .year): String(year)
    case (.flag(let flag), .yesNo): flag ? "yes" : "no"
    case (.options(let options), .set): options.joined(separator: "|")
    default: nil
    }
  }

  /// A value written for the note, for what the template can't carry.
  static func text(_ value: FieldValue) -> String? {
    switch value {
    case .text(let text): text
    case .number(let number): number.formatted(.number.grouping(.never).locale(Locale(identifier: "en")))
    case .flag(let flag): flag ? "yes" : "no"
    case .date(let date): date.formatted(.iso8601.year().month().day())
    case .year(let year): String(year)
    case .yearRange(let from, let to): "\(from)–\(to)"
    case .money: nil
    case .options(let options): options.joined(separator: "|")
    case .entries(let entries):
      entries.map { $0.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ") }
        .joined(separator: "; ")
    case .photo: nil
    }
  }

  /// RFC 4180: a cell with a comma, a quote or a line break is quoted, quotes doubled.
  static func cell(_ text: String) -> String {
    guard text.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return text }
    return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }
}

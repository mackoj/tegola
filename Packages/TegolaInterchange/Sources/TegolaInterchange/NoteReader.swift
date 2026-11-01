import Foundation
public import TegolaCatalogue
import TegolaModel

/// The rule-based cell reader: what the import uses without Apple Intelligence, and the reading the tests pin
/// (D-65). It reads the notes collectors put in brackets after a title, in French and English, against the cell's
/// type:
///
/// - **Parts** ("cartouche + manuel") fill the type's What's inside slots, and a cart or disc its media.
/// - **Damage** ("boite endommagé", "cartouche ko") grades that part at the scale's worst step; **missing**
///   ("manque manuel") grades it Missing.
/// - "dédicace JDG" is signed by JDG; "doublon" says this cell is a second copy; "complet" is every part.
/// - "/" in the title is a bundle of works.
///
/// Everything it doesn't read stays in the note as written, and so does "digital", which no field holds. The title
/// is the text outside the brackets, typos and all: matching fixes those, never the reader.
public struct NoteReader: CellExtracting {
  public init() {}

  public func extract(_ cells: [ImportCell]) async throws -> [ExtractedCell] {
    cells.map(read)
  }

  public func read(_ cell: ImportCell) -> ExtractedCell {
    var text = cell.text.trimmingCharacters(in: .whitespacesAndNewlines)
    var result = ExtractedCell(title: text)
    var unread: [String] = []

    // A trailing "doublon", outside the brackets.
    if let range = text.range(of: #"\s+doublon\s*$"#, options: [.regularExpression, .caseInsensitive]) {
      text.removeSubrange(range)
      result.noticed.insert(.duplicate)
    }
    var groups: [String] = []
    var title = text
    while let range = title.range(of: #"\([^()]*\)"#, options: .regularExpression) {
      groups.append(String(title[range].dropFirst().dropLast()))
      title.replaceSubrange(range, with: " ")
    }
    title = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    result.title = title.isEmpty ? text : title

    var parts = Parts(type: cell.type)
    for group in groups {
      for token in group.split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) where !token.isEmpty {
        if !parts.read(token, into: &result) { unread.append(token) }
      }
    }
    parts.write(into: &result)

    let works = result.title.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
    if works.count > 1, !works.contains(where: \.isEmpty), cell.type.field("contains") != nil {
      result.values[.field("contains")] = .entries(works.map { ["work": $0] })
      result.noticed.insert(.bundle)
    }
    if !unread.isEmpty { result.values[.notes] = .text(unread.joined(separator: " + ")) }
    return result
  }
}

/// What the brackets said about the type's parts, written once every token is read.
struct Parts {
  enum Part: CaseIterable {
    case media, box, manual, insert
  }

  let type: EffectiveType
  var present: Set<Part> = []
  var grades: [Part: String] = [:]
  var media: String?

  init(type: EffectiveType) {
    self.type = type
  }

  // Words are compared folded: lowercase, no accents.
  static let words: [Part: [String]] = [
    .media: ["cartouche", "cartridge", "cart", "cd", "disc", "disque", "dvd", "cassette", "vinyle", "vinyl"],
    .box: ["boite", "box", "boitier", "case", "jaquette"],
    .manual: ["manuel", "manual", "notice", "livret", "booklet"],
    .insert: ["cale", "insert", "inner tray"],
  ]
  static let mediaOptions: [String: String] = [
    "cartouche": "Cartridge", "cartridge": "Cartridge", "cart": "Cartridge",
    "cd": "Optical disc", "disc": "Optical disc", "disque": "Optical disc", "dvd": "Optical disc",
  ]
  /// The slot names a part may have in a type's set field (`inserts`).
  static let slots: [Part: [String]] = [
    .media: ["cart", "disc", "cartridge"], .box: ["box", "case"], .manual: ["manual", "booklet"],
    .insert: ["insert", "inner tray"],
  ]
  /// Words in a ladder axis's label that name the part it grades ("Cart / disc", "Box", "Manual").
  static let axisWords: [Part: [String]] = [
    .media: ["cart", "disc", "media"], .box: ["box", "case"], .manual: ["manual", "booklet"],
  ]
  static let damaged = ["endommage", "endommagee", "abime", "abimee", "use", "usee", "damaged", "worn"]
  static let broken = ["ko", "hs", "casse", "cassee", "broken", "faulty", "dead"]
  static let missing = ["manque", "sans", "missing", "no", "without"]
  static let complete = ["complet", "complete", "cib"]
  static let signed = ["dedicace", "dedicacee", "signe", "signee", "signed", "autographe"]
  static let digital = ["digital", "dematerialise", "numerique", "download"]

  static func fold(_ text: String) -> String {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
  }

  static func part(named word: String) -> Part? {
    Part.allCases.first { words[$0]?.contains(word) == true }
  }

  /// Reads one "+"-separated token, or says it couldn't, leaving it for the note.
  mutating func read(_ token: String, into result: inout ExtractedCell) -> Bool {
    let original = token.split(whereSeparator: \.isWhitespace).map(String.init)
    let words = original.map(Self.fold)
    guard let first = words.first else { return false }
    if words.count == 1 {
      if Self.digital.contains(first) {
        result.noticed.insert(.digital)
        return false  // read, but no field holds it: the note keeps the word
      }
      if first == "doublon" {
        result.noticed.insert(.duplicate)
        return true
      }
      if Self.complete.contains(first) {
        present.formUnion([.media, .box, .manual])
        return canHold([.media, .box, .manual])
      }
    }
    if Self.missing.contains(first), words.count == 2, let part = Self.part(named: words[1]) {
      result.noticed.insert(.imperfect)
      guard type.allowMissing, axis(for: part) != nil else { return false }
      grades[part] = "Missing"
      return true
    }
    if Self.missing.contains(first) {
      result.noticed.insert(.imperfect)  // "manque cd audio": something's missing, but not a part this type grades
      return false
    }
    if Self.signed.contains(first), words.count > 1 {
      sign(original.dropFirst().joined(separator: " "), into: &result)
      return true
    }
    // A part, then what's wrong with it or who signed it: "cartouche ko", "cartouche dédicace JDG".
    guard let part = Self.part(named: first) else { return false }
    let rest = Array(words.dropFirst())
    if rest.isEmpty {
      present.insert(part)
      if part == .media { media = Self.mediaOptions[first] ?? media }
      return canHold([part]) || (part == .media && mediaFits(Self.mediaOptions[first]))
    }
    if rest.count == 1, Self.damaged.contains(rest[0]) || Self.broken.contains(rest[0]),
      let worst = type.conditions.last, axis(for: part) != nil
    {
      present.insert(part)
      if part == .media { media = Self.mediaOptions[first] ?? media }
      grades[part] = worst
      result.noticed.insert(.imperfect)
      return true
    }
    if rest.count > 1, Self.signed.contains(rest[0]) {
      present.insert(part)
      if part == .media { media = Self.mediaOptions[first] ?? media }
      sign(original.dropFirst(2).joined(separator: " "), into: &result)
      return canHold([part]) || (part == .media && mediaFits(Self.mediaOptions[first]))
    }
    return false
  }

  func sign(_ name: String, into result: inout ExtractedCell) {
    guard type.field("signed") != nil else { return }
    result.values[.field("signed")] = .entries([["by": name]])
    result.noticed.insert(.signed)
  }

  /// The type's set of parts, when it has one with slots (`inserts`).
  var slotField: EffectiveField? {
    type.fields.first { $0.field.kind == .set && $0.field.slotsFrom != nil && !$0.isHidden }
  }

  func slot(for part: Part) -> String? {
    guard let options = slotField?.field.options else { return nil }
    return Self.slots[part]?.first { options.contains($0) }
  }

  func axis(for part: Part) -> EffectiveField? {
    type.fields.first { field in
      field.field.ladderAxis != nil && !field.isHidden
        && Self.axisWords[part]?.contains { Self.fold(field.field.label).contains($0) } == true
    }
  }

  func canHold(_ parts: Set<Part>) -> Bool { parts.allSatisfy { slot(for: $0) != nil } }

  /// A medium the type's media field takes: always when a subtype has preset it, since the cell agrees with the
  /// column; otherwise when it's one of the field's options.
  func mediaFits(_ option: String?) -> Bool {
    guard let option, let field = type.field("media") else { return false }
    return field.isHidden || field.field.options.contains(option)
  }

  func write(into result: inout ExtractedCell) {
    let slots = present.compactMap(slot(for:)).sorted()
    if let field = slotField, !slots.isEmpty { result.values[.field(field.key)] = .options(slots) }
    if let media, let field = type.field("media"), !field.isHidden, field.field.options.contains(media) {
      result.values[.field("media")] = .text(media)
    }
    for (part, grade) in grades {
      if let axis = axis(for: part) { result.values[.axis(axis.key)] = .text(grade) }
    }
  }
}

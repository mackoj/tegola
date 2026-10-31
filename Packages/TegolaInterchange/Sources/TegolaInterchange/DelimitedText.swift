public import Foundation

/// A spreadsheet saved as text: CSV, TSV, or anything else a spreadsheet writes (PD-048: "any column order,
/// separator, encoding"). The import's first step reads it into rows of cells, guessing the encoding and separator;
/// it never interprets a cell.
public struct DelimitedText: Hashable, Sendable {
  public let separator: Character
  public let encoding: String.Encoding
  /// Every row as written, header included, each cell trimmed of surrounding spaces. Rows keep their own lengths:
  /// a ragged file stays ragged, and nothing is padded or dropped.
  public let rows: [[String]]

  public var header: [String] { rows.first ?? [] }
  public var body: ArraySlice<[String]> { rows.dropFirst() }

  /// The separators tried, in order of preference when two fit equally well.
  public static let candidateSeparators: [Character] = [",", ";", "\t", "|"]

  public init(data: Data) throws {
    let (text, encoding) = try Self.decode(data)
    let separator = Self.guessSeparator(in: text)
    self.encoding = encoding
    self.separator = separator
    self.rows = Self.parse(text, separator: separator)
  }

  /// UTF-8 (with or without a byte-order mark), UTF-16 with a byte-order mark, then Windows-1252 and Latin-1, which
  /// decode any bytes, so a spreadsheet exported by an old Excel still opens.
  static func decode(_ data: Data) throws -> (String, String.Encoding) {
    if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
      guard let text = String(data: data, encoding: .utf16) else { throw DelimitedTextError.unreadable }
      return (text, .utf16)
    }
    let body = data.starts(with: [0xEF, 0xBB, 0xBF]) ? data.dropFirst(3) : data
    if let text = String(data: body, encoding: .utf8) { return (text, .utf8) }
    if let text = String(data: body, encoding: .windowsCP1252) { return (text, .windowsCP1252) }
    if let text = String(data: body, encoding: .isoLatin1) { return (text, .isoLatin1) }
    throw DelimitedTextError.unreadable
  }

  /// The separator that splits the first lines into the most columns, as consistently as possible. Quoted text is
  /// ignored, so a comma inside "Doom, the boxed edition" doesn't count.
  static func guessSeparator(in text: String) -> Character {
    let sample = text.split(whereSeparator: \.isNewline).prefix(20).map(String.init)
    var best: (separator: Character, score: Int) = (",", 0)
    for separator in candidateSeparators {
      let counts = sample.map { line in parse(line, separator: separator).first.map { $0.count - 1 } ?? 0 }
      guard let first = counts.first, first > 0 else { continue }
      // Lines that agree with the first line's count, times the number of columns.
      let score = counts.filter { $0 == first }.count * (first + 1)
      if score > best.score { best = (separator, score) }
    }
    return best.separator
  }

  /// RFC 4180, leniently: quotes may wrap a cell, `""` is a quote inside one, quoted cells may span lines, and
  /// CRLF, LF and CR all end a row. A quote in the middle of an unquoted cell is kept as text.
  static func parse(_ text: String, separator: Character) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var cell = ""
    var inQuotes = false
    var cellWasQuoted = false
    var characters = text.makeIterator()
    var pending: Character? = nil

    func endCell() {
      row.append(cellWasQuoted ? cell : cell.trimmingCharacters(in: .whitespaces))
      cell = ""
      cellWasQuoted = false
    }
    func endRow() {
      endCell()
      if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
      row = []
    }

    while let character = pending ?? characters.next() {
      pending = nil
      if inQuotes {
        if character == "\"" {
          if let next = characters.next() {
            if next == "\"" { cell.append("\"") } else { inQuotes = false; pending = next }
          } else {
            inQuotes = false
          }
        } else {
          cell.append(character)
        }
        continue
      }
      switch character {
      case "\"" where cell.trimmingCharacters(in: .whitespaces).isEmpty && !cellWasQuoted:
        cell = ""
        inQuotes = true
        cellWasQuoted = true
      case separator:
        endCell()
      case "\r\n", "\n", "\r":
        endRow()
      default:
        cell.append(character)
      }
    }
    if !cell.isEmpty || !row.isEmpty { endRow() }
    return rows
  }
}

public enum DelimitedTextError: Error, Equatable, Sendable {
  case unreadable
}

import Foundation
import TegolaCatalogue
import TegolaModel

/// Turns a cell the reader read into the plan's row, the same way for every importer: the title, the importer's own
/// values, the reader's, the notes of both, and the question the exceptions queue asks. Every draft is one `plan` accepts, so **Build my shelf** can't be refused over one row: a draft it would
/// refuse falls back to the cell as written, as the title (49 Q2: nothing is dropped).
struct RowBuilder {
  let catalogue: Catalogue

  func rows(
    _ extracted: ExtractedCell,
    written: String,
    type: EffectiveType,
    values importerValues: [FieldKey: FieldValue],
    ownership: ShelfObject.Ownership,
    sheet: String,
    line: Int,
    shelf: String?
  ) -> ImportPlan.Row {
    var values = importerValues.merging(extracted.values) { mine, _ in mine }
    var notes = [extracted.values[.notes], importerValues[.notes]].compactMap { value -> String? in
      if case .text(let text) = value, !text.isEmpty { text } else { nil }
    }
    let title = extracted.title.trimmingCharacters(in: .whitespacesAndNewlines)
    values[.title] = .text(title.isEmpty ? written : title)
    if ownership == .wanted {
      // You can't grade what you don't have: a wanted row keeps what it said about condition as words.
      let grades = values.keys.filter { if case .axis = $0 { true } else { $0 == .condition } }
      if !grades.isEmpty {
        grades.forEach { values[$0] = nil }
        notes.append(written)
      }
    }
    values[.notes] = notes.isEmpty ? nil : .text(notes.joined(separator: "\n"))

    var draft = ObjectDraft(type: type.type, subtype: type.subtype, values: values, ownership: ownership)
    if !accepts(draft) {
      draft = ObjectDraft(
        type: type.type,
        subtype: type.subtype,
        values: [.title: .text(written)],
        ownership: ownership
      )
    }
    let question: ImportPlan.Question? =
      if extracted.noticed.contains(.digital) {
        .digital
      } else if extracted.noticed.contains(.bundle) {
        .bundle(works: extracted.works)
      } else {
        nil
      }
    return ImportPlan.Row(
      draft: draft,
      written: written,
      sheet: sheet,
      line: line,
      shelf: shelf,
      noticed: extracted.noticed,
      question: question
    )
  }

  /// Whether `plan` would add this draft from an import. Ids and the date don't matter to the rules.
  func accepts(_ draft: ObjectDraft) -> Bool {
    let context = PlanContext(at: .distantPast, source: .import, catalogue: catalogue) { Self.anyID }
    return (try? plan(.add(draft, to: .new(name: "Import"), origin: .imported), on: Shelf(), context: context)) != nil
  }

  static let anyID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

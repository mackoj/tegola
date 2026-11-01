#if canImport(SwiftUI)
  public import SwiftUI
  public import TegolaCatalogue
  public import TegolaModel
  import TegolaDesignSystem

  // How the shelf's values read on screen, shared by every feature that shows an object: the object screen, rows,
  // Find's "what matched", the edit form's previews. Words come from this target's catalog; data stays verbatim.

  extension FieldValue {
    /// The value as one line of text. Dates and numbers follow the reader's locale through the environment.
    public func text(unit: String? = nil) -> Text {
      switch self {
      case .text(let text): Text(verbatim: text)
      case .number(let number):
        unit.map { Text(verbatim: "\(number.formatted()) \($0)") } ?? Text(number, format: .number)
      case .flag(let flag): flag ? Text("Yes", bundle: .module) : Text("No", bundle: .module)
      case .date(let date): Text(date, format: .dateTime.day().month(.abbreviated).year())
      case .year(let year): Text(verbatim: String(year))
      case .yearRange(let from, let to): Text(verbatim: "\(from) – \(to)")
      case .money(let money): Text(money.amount, format: .currency(code: money.currency.code))
      case .options(let options): Text(verbatim: options.joined(separator: " · "))
      case .entries(let entries): Text("\(entries.count) entries", bundle: .module)
      case .photo: TegolaAction.photo.label
      }
    }
  }

  extension ShelfEvent {
    /// A return's history line: who it came back from, closed by the collector alone (one-sided, PD-160), how it came
    /// back, and the collector's words.
    static func returnLine(from name: String, cameBack: Loan.CameBack?, words: String?) -> String {
      let shape: String? =
        switch cameBack {
        case .sameShape: String(localized: "same shape", bundle: .module)
        case .damaged: String(localized: "damaged", bundle: .module)
        case .somethingMissing: String(localized: "something missing", bundle: .module)
        case nil: nil
        }
      let head = String(localized: "Back from \(name), closed by you", bundle: .module)
      return ([head, shape, words].compactMap { $0 }).joined(separator: " · ")
    }

    /// One line in the History slot (board 36): what happened, in the collector's words where they wrote some.
    public func historyLine(shelf: Shelf, type: EffectiveType?) -> Text {
      func person(_ loan: Loan) -> String { shelf.persons[loan.personID]?.name ?? "" }
      func movedTo(_ name: String) -> Text { Text("Moved to \(name)", bundle: .module) }
      func lentTo(_ name: String) -> Text { Text("Lent to \(name)", bundle: .module) }
      func borrowedFrom(_ name: String) -> Text { Text("Borrowed from \(name)", bundle: .module) }
      // The person a loan was with: names can't be changed in v1, so the loan's person is the name at the time (D-3,
      // D-76).
      func person(of loan: LoanID) -> String { shelf.loans[loan].map(person) ?? "" }
      func givenBackTo(_ name: String) -> Text { Text("Given back to \(name)", bundle: .module) }
      return switch kind {
      case .added(_, let origin):
        switch origin {
        case .typed: Text("Added", bundle: .module)
        case .captured: Text("Captured", bundle: .module)
        case .imported: Text("Imported", bundle: .module)
        case .firstPiece(let story): Text("First piece · \(story)", bundle: .module)
        }
      case .edited(_, let changes):
        Text("Edited · \(Self.labels(changes.keys, type: type))", bundle: .module)
      case .enriched(_, let changes):
        Text("Details filled in · \(Self.labels(changes.keys, type: type))", bundle: .module)
      case .confirmed: Text("Confirmed", bundle: .module)
      case .photoAttached: Text("Photo added", bundle: .module)
      case .placed(_, let place):
        if let place, let path = shelf.placePath(of: place) {
          Text("Placed · \(path)", bundle: .module)
        } else {
          Text("Unplaced", bundle: .module)
        }
      case .moved(_, let collection): movedTo(shelf.collections[collection]?.name ?? "")
      case .lent(let loan): lentTo(person(loan))
      case .borrowed(let loan): borrowedFrom(person(loan))
      case .returned(let loan, _, let words, let cameBack):
        Text(verbatim: Self.returnLine(from: person(of: loan), cameBack: cameBack, words: words))
      case .gaveBack(let loan, _): givenBackTo(person(of: loan))
      case .logged(_, let kind, let note):
        switch (kind, note.isEmpty) {
        case (ShelfEvent.Kind.servicedKind, true): Text("Serviced", bundle: .module)
        case (ShelfEvent.Kind.servicedKind, false): Text("Serviced · \(note)", bundle: .module)
        case (ShelfEvent.Kind.backedUpKind, true): Text("Backed up", bundle: .module)
        case (ShelfEvent.Kind.backedUpKind, false): Text("Backed up · \(note)", bundle: .module)
        case (_, true): Text(verbatim: kind.capitalized)
        case (_, false): Text(verbatim: "\(kind.capitalized) · \(note)")
        }
      case .signalDismissed: Text("Estimate dismissed", bundle: .module)
      case .ownershipChanged(_, let ownership):
        ownership == .owned ? Text("It arrived", bundle: .module) : Text(verbatim: ownership.rawValue)
      case .letGo(_, let letGo):
        switch letGo.reason {
        case .sold: Text("Let go · sold", bundle: .module)
        case .gifted: Text("Let go · gifted", bundle: .module)
        case .traded: Text("Let go · traded", bundle: .module)
        case .lost: Text("Let go · lost", bundle: .module)
        case .broken: Text("Let go · broken", bundle: .module)
        }
      case .promoted: Text("One copy taken out", bundle: .module)
      case .collectionCreated, .collectionRenamed, .placeCreated, .personCreated, .workCreated, .placesMerged, .wanted,
        .grailChanged, .mightLetGoChanged, .quantityAdjusted, .batchImported, .batchUndone:
        Text(verbatim: kind.name)
      }
    }

    /// The changed keys as the collector knows them: the type's labels, not the stored keys.
    static func labels(_ keys: some Collection<FieldKey>, type: EffectiveType?) -> String {
      keys.sorted().map { key in
        switch key {
        case .field(let name), .axis(let name): type?.field(name)?.field.label ?? name
        default: key.description
        }
      }
      .joined(separator: ", ")
    }
  }

#endif

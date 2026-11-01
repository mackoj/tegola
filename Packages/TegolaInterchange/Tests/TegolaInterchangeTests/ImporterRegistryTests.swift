import Foundation
import TegolaCatalogue
import TegolaModel
import Testing

@testable import TegolaInterchange

@Suite struct ImporterRegistryTests {
  /// An importer that recognises what it's told to.
  struct Fixed: Importer {
    let id: ImporterID
    let answer: Recognition

    func recognises(_ input: ImportInput) -> Recognition { answer }
    func plan(_ input: ImportInput, catalogue: Catalogue, extraction: some CellExtracting) async throws -> ImportPlan {
      ImportPlan(importer: id, fileName: input.fileName, collectionName: input.collectionName, rows: [])
    }
  }

  static let input = ImportInput(fileName: "Jeux collection.csv", data: Data("a;b\n".utf8))

  @Test func theMostCertainWinsAndTiesKeepTheRegistrysOrder() {
    let registry = ImporterRegistry([
      Fixed(id: "first-likely", answer: .likely(reason: "a list")),
      Fixed(id: "never", answer: .no),
      Fixed(id: "certain", answer: .certain),
      Fixed(id: "second-likely", answer: .likely(reason: "a grid")),
    ])
    #expect(registry.candidates(for: Self.input).map(\.importer.id) == ["certain", "first-likely", "second-likely"])
    #expect(registry.best(for: Self.input)?.id == "certain")
    #expect(ImporterRegistry([Fixed(id: "never", answer: .no)]).best(for: Self.input) == nil)
  }

  @Test(arguments: [
    ("Jeux collection.csv", "Jeux"), ("vinyles.tsv", "vinyles"), ("My Collection.csv", "My"),
    ("collection.csv", "collection"), ("Board games", "Board games"),
  ])
  func theCollectionIsNamedAfterTheFile(_ fileName: String, _ name: String) {
    #expect(ImportInput(fileName: fileName, data: Data()).collectionName == name)
  }

  @Test func aPlanCountsWhatItNoticedAndBecomesOneBatch() {
    func row(_ title: String, _ shelf: String, _ noticed: Set<ImportPlan.Notice> = []) -> ImportPlan.Row {
      ImportPlan.Row(
        draft: ObjectDraft(type: "video-game", values: [.title: .text(title)]),
        written: title,
        sheet: "Jeux",
        line: 2,
        shelf: shelf,
        noticed: noticed,
        question: noticed.contains(.digital) ? .digital : nil
      )
    }
    let plan = ImportPlan(
      importer: "spreadsheet",
      fileName: "Jeux collection.csv",
      collectionName: "Jeux",
      rows: [row("Doom", "PC"), row("Tetris", "Game Boy", [.imperfect]), row("It take two", "Ps5", [.digital])]
    )
    #expect(plan.shelves == ["PC", "Game Boy", "Ps5"])
    #expect(plan.types == ["video-game"])
    #expect(plan.count(.imperfect) == 1 && plan.count(.signed) == 0)
    #expect(plan.toSort.map(\.written) == ["It take two"])
    let batch = plan.batch()
    #expect(batch.collectionName == "Jeux" && batch.importer == "spreadsheet" && batch.rows.count == 3)
  }
}

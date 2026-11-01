import Foundation
import TegolaCatalogue
import TegolaModel
import Testing

@testable import TegolaInterchange

/// The template's fast lane (49 §03B): page 49's four rows, written in the template's columns.
@Suite struct TemplateImporterTests {
  static let catalogue = try! Catalogue.bundled()

  static let csv = """
    type,subtype,title,parts,condition,signed_by,contains,note,region
    video-game,n64,Super Mario 64,box|cart,boxCondition:Poor,,,,PAL
    video-game,,Teenage Mutant Ninja Turtles,manual,,JDG,,,PAL
    video-game,,Heavy Rain + Beyond Two Souls,,,,Heavy Rain|Beyond: Two Souls,,PAL
    video-game,,Moonwalker,,mediaCondition:Poor,,,cartouche ko,Europe
    wine,,Château Margaux 1996,,,,,,
    """

  static func plan(_ csv: String = csv) async throws -> ImportPlan {
    let input = ImportInput(fileName: "tegola.csv", data: Data(csv.utf8))
    return try await TemplateImporter().plan(input, catalogue: catalogue, extraction: NoteReader())
  }

  @Test func itsHeaderIsCertainAndWinsOverTheSpreadsheet() {
    let input = ImportInput(fileName: "tegola.csv", data: Data(Self.csv.utf8))
    #expect(TemplateImporter().recognises(input) == .certain)
    #expect(ImporterRegistry.v1.best(for: input)?.id == "tegola-template")
    let jeux = ImportInput(fileName: "Jeux.csv", data: Data("Ps1;N64\nDoom;Mario 64\n".utf8))
    #expect(TemplateImporter().recognises(jeux) == .no)
    #expect(ImporterRegistry.v1.best(for: jeux)?.id == "spreadsheet")
    // The fixed columns keep their order: a shuffled header is any other spreadsheet.
    let shuffled = ImportInput(fileName: "x.csv", data: Data("title,type\nDoom,video-game\n".utf8))
    #expect(TemplateImporter().recognises(shuffled) == .no)
  }

  @Test func everyColumnLandsWhereItSaysAndNothingIsGuessed() async throws {
    let plan = try await Self.plan()
    #expect(plan.guessed.isEmpty && plan.toSort.isEmpty)
    #expect(plan.rows.count == 5)
    let mario = plan.rows[0].draft
    #expect(mario.type == "video-game" && mario.subtype == "n64")
    #expect(mario.values[.field("inserts")] == .options(["box", "cart"]))
    #expect(mario.values[.axis("boxCondition")] == .text("Poor"))
    #expect(mario.values[.field("region")] == .text("PAL"))
    #expect(plan.rows[0].shelf == "Nintendo 64")
    #expect(plan.rows[1].draft.values[.field("signed")] == .entries([["by": "JDG"]]))
    #expect(
      plan.rows[2].draft.values[.field("contains")]
        == .entries([["work": "Heavy Rain"], ["work": "Beyond: Two Souls"]])
    )
    // A value that doesn't fit its field stays in the note, with its header.
    #expect(plan.rows[3].draft.values[.notes] == .text("cartouche ko\nregion: Europe"))
    #expect(plan.rows[3].draft.values[.field("region")] == nil)
  }

  @Test func aTypeThatHasntShippedIsAThingThatKeepsTheRest() async throws {
    let plan = try await Self.plan()
    let wine = plan.rows[4].draft
    #expect(wine.type == "thing" && wine.awaitingType == "wine")
    #expect(wine.values == [.title: .text("Château Margaux 1996")])
    let unknown = try await Self.plan("type,title,note,colour\nspaceship,Millennium Falcon,a hunk of junk,grey\n")
    #expect(unknown.rows[0].draft.awaitingType == nil)
    #expect(unknown.rows[0].draft.values[.notes] == .text("a hunk of junk\ntype: spaceship\ncolour: grey"))
  }

  @Test func everyRowIsOnePlanTakes() async throws {
    let plan = try await Self.plan()
    let builder = RowBuilder(catalogue: Self.catalogue)
    #expect(plan.rows.allSatisfy { builder.accepts($0.draft) })
  }
}

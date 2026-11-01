import Foundation
import TegolaCatalogue
import TegolaModel
import Testing

@testable import TegolaInterchange

/// A Discogs collection export, in the columns and grade words Discogs writes.
@Suite struct DiscogsCSVImporterTests {
  static let catalogue = try! Catalogue.bundled()

  static let csv = """
    Catalog#,Artist,Title,Label,Format,Rating,Released,release_id,CollectionFolder,Date Added,Collection Media Condition,Collection Sleeve Condition,Collection Notes,Signed
    7243 8 55229 1 7,Radiohead,OK Computer,Parlophone,"2xLP, Album, RE",5,1997,4950798,Uncategorized,2021-03-04 10:12:00,Very Good Plus (VG+),Near Mint (NM or M-),Gatefold,
    CDP 7 46440 2,Nirvana (2),Nevermind,DGC,"CD, Album",0,1991,367084,Uncategorized,2021-03-04 10:13:00,Good Plus (G+),No Cover,,
    none,Unknown Artist,Mixtape 94,Not On Label,"Cass, Comp",0,0,111,Tapes,2021-03-04 10:14:00,,,,yes
    SR-1,Someone,Strange Thing,Self,"Flexi-disc, 7\"\"",0,1980,222,Uncategorized,2021-03-04 10:15:00,,Generic,,
    """

  static func plan() async throws -> ImportPlan {
    let input = ImportInput(fileName: "collection-20210304.csv", data: Data(csv.utf8))
    return try await DiscogsCSVImporter().plan(input, catalogue: catalogue, extraction: NoteReader())
  }

  @Test func itsHeaderIsCertain() {
    let input = ImportInput(fileName: "collection.csv", data: Data(Self.csv.utf8))
    #expect(DiscogsCSVImporter().recognises(input) == .certain)
    #expect(ImporterRegistry.v1.best(for: input)?.id == "discogs-csv")
  }

  @Test func aReleaseLandsInMusicWithItsMediumAsTheSubtype() async throws {
    let plan = try await Self.plan()
    #expect(plan.rows.count == 4 && plan.types == ["music"])
    #expect(plan.shelves == ["Vinyl", "CD", "Cassette"])
    let ok = plan.rows[0].draft
    #expect(ok.subtype == "vinyl")
    #expect(ok.values[.title] == .text("OK Computer") && ok.values[.subtitle] == .text("Radiohead"))
    #expect(ok.values[.year] == .year(1997))
    #expect(ok.values[.field("format")] == .text("2×LP"))
    #expect(ok.values[.field("label")] == .text("Parlophone"))
    #expect(ok.values[.field("catalogNumber")] == .text("7243 8 55229 1 7"))
    #expect(ok.values[.condition] == .text("VG+"))
    #expect(ok.values[.field("packagingCondition")] == .text("Near Mint"))
    // Discogs' added date is when it was catalogued there, never `acquired` (D-14).
    #expect(ok.values[.acquired] == nil)
    #expect(
      ok.values[.notes]
        == .text(
          "Gatefold\nFormat: Album, RE\nRating: 5\nDiscogs release: 4950798\nAdded to Discogs: 2021-03-04 10:12:00"
        )
    )
  }

  @Test func whatMusicCantHoldStaysInTheNote() async throws {
    let plan = try await Self.plan()
    let nevermind = plan.rows[1].draft
    #expect(nevermind.values[.subtitle] == .text("Nirvana"))
    #expect(nevermind.values[.condition] == nil)
    #expect(nevermind.values[.field("packagingCondition")] == .text("Missing"))
    #expect(nevermind.values[.notes]?.searchText.contains("Media: Good Plus (G+)") == true)
    let tape = plan.rows[2].draft
    #expect(tape.subtype == "cassette" && tape.values[.year] == nil && tape.values[.field("catalogNumber")] == nil)
    #expect(tape.values[.notes]?.searchText.contains("Folder: Tapes") == true)
    #expect(tape.values[.notes]?.searchText.contains("Signed: yes") == true)
    let flexi = plan.rows[3].draft
    #expect(flexi.subtype == nil)
    #expect(flexi.values[.notes]?.searchText.contains("Format: Flexi-disc, 7\"") == true)
    #expect(flexi.values[.notes]?.searchText.contains("Sleeve: Generic") == true)
    let builder = RowBuilder(catalogue: Self.catalogue)
    #expect(plan.rows.allSatisfy { builder.accepts($0.draft) })
  }

  @Test(
    arguments: [
      ("LP", "vinyl", "LP", [String]()), ("2xLP, Album, RE", "vinyl", "2×LP", ["Album", "RE"]),
      ("7\", Single", "vinyl", "7\"", ["Single"]), ("2x12\", Album", "vinyl", nil, ["2x12\"", "Album"]),
      ("CD, Album", "cd", "CD", ["Album"]), ("3xCD, Box", "cd", "3×CD", ["Box"]),
      ("Cass, Album", "cassette", "Cassette", ["Album"]),
    ] as [(String, String?, String?, [String])]
  )
  func formats(_ text: String, _ subtype: String?, _ format: String?, _ rest: [String]) {
    let read = DiscogsCSVImporter.format(text)
    #expect(read.subtype == subtype && read.format == format && read.rest == rest)
  }
}

extension FieldValue {
  var searchText: String { if case .text(let text) = self { text } else { "" } }
}

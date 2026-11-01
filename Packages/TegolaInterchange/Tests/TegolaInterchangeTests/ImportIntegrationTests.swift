import Foundation
import TegolaCatalogue
import TegolaFixtures
import TegolaModel
import Testing

@testable import TegolaInterchange

/// M6's exit test, as far as the phone goes without the server (PLAN F9): the real `Jeux collection.csv`, read by the
/// spreadsheet importer with the rule-based reader, confirmed as one sentence, and written as one batch.
@Suite struct ImportIntegrationTests {
  static let catalogue = try! Catalogue.bundled()

  static func jeux() async throws -> ImportPlan {
    let input = ImportInput(fileName: Fixture.jeuxCollection.rawValue, data: try Fixture.jeuxCollection.data())
    return try await SpreadsheetImporter().plan(input, catalogue: catalogue, extraction: NoteReader())
  }

  @Test func jeuxCollectionLandsAsOneCollectionWithAShelfPerPlatform() async throws {
    let plan = try await Self.jeux()
    // "485 video games on 20 platforms, into a collection called Jeux."
    #expect(plan.collectionName == "Jeux")
    #expect(plan.types == ["video-game"])
    #expect(plan.rows.count == 485)
    #expect(plan.shelves.count == 20)
    #expect(Array(plan.shelves.prefix(3)) == ["PlayStation", "Ps2", "Ps3"])
    #expect(
      plan.guessed == [
        ImportPlan.Guess(written: "Ps1", readAs: "PlayStation"), .init(written: "N64", readAs: "Nintendo 64"),
      ]
    )
    let subtypes = Dictionary(grouping: plan.rows, by: { $0.draft.subtype ?? "-" }).mapValues(\.count)
    #expect(subtypes["ps1"] == 73 && subtypes["n64"] == 9 && subtypes["game-boy"] == 8 && subtypes["saturn"] == 4)
    // A platform without a subtype is the platform as written, never renamed.
    let advance = plan.rows.filter { $0.shelf == "Game Boy advence" }
    #expect(
      advance.count == 10 && advance.allSatisfy { $0.draft.values[.field("platform")] == .text("Game Boy advence") }
    )
  }

  @Test func everyCellIsKept() async throws {
    let plan = try await Self.jeux()
    let table = try DelimitedText(data: try Fixture.jeuxCollection.data())
    for (offset, row) in table.body.enumerated() {
      for cell in row where !cell.isEmpty {
        #expect(plan.rows.contains { $0.line == offset + 2 && $0.written == cell }, "dropped: \(cell)")
      }
    }
    // Nothing fell back: every cell was read into a draft `plan` takes as it is.
    let builder = RowBuilder(catalogue: Self.catalogue)
    #expect(plan.rows.allSatisfy { builder.accepts($0.draft) })
    #expect(plan.rows.allSatisfy { $0.draft.values[.title] != nil })
  }

  @Test func notesBecomePartsSignedAndBundles() async throws {
    let plan = try await Self.jeux()
    // Page 49's payoff: Imperfect (3), Duplicate (1), Signed (1).
    #expect(plan.count(.imperfect) == 3)
    #expect(plan.count(.duplicate) == 1)
    #expect(plan.count(.signed) == 1)
    #expect(plan.count(.bundle) == 4)
    #expect(plan.count(.digital) == 9)
    let turtles = try #require(plan.rows.first { $0.written.hasPrefix("Tortue ninja") })
    #expect(turtles.draft.values[.field("signed")] == .entries([["by": "JDG"]]))
    #expect(turtles.shelf == "Nes")
    let fantasy = plan.rows.filter { $0.written.hasPrefix("Fantasy zone") }
    #expect(fantasy.map { $0.noticed.contains(.duplicate) } == [false, true])
  }

  /// Under 5% of rows need a fix: the exceptions queue holds only the bundles and the digital copies (49 §04).
  @Test func fewerThanOneRowInTwentyNeedsAFix() async throws {
    let plan = try await Self.jeux()
    #expect(plan.toSort.count == 12)
    #expect(Double(plan.toSort.count) / Double(plan.rows.count) < 0.05)
  }

  @Test func theBatchIsOneCommandThatPlanTakes() async throws {
    let plan = try await Self.jeux()
    let ids = LockedCounter()
    let context = PlanContext(
      at: Date(timeIntervalSince1970: 1_800_000_000),
      source: .import,
      catalogue: Self.catalogue
    ) {
      ids.next()
    }
    let events = try TegolaModel.plan(.importBatch(plan.batch()), on: Shelf(), context: context)
    let shelf = apply(events, to: Shelf())
    #expect(shelf.objects.count == 485)
    #expect(shelf.collections.values.map(\.name) == ["Jeux"])
    #expect(shelf.objects.values.allSatisfy { $0.identity == .unconfirmed && $0.acquiredAt == nil })
    #expect(shelf.objects.values.count { $0.title == "Fantasy zone" } == 2)
  }

  @Test func aWishlistTabIsWantedObjects() async throws {
    let input = ImportInput(
      fileName: "Jeux.csv",
      sheets: [
        .init(name: "Jeux", data: Data("Ps1;N64\nTomb raider 1 (cd);Mario 64\n".utf8)),
        .init(name: "Recherché.csv", data: Data("Ps1;N64\nVagrant Story;Mario Kart 64 (boite endommagé)\n".utf8)),
      ]
    )
    let plan = try await SpreadsheetImporter().plan(input, catalogue: Self.catalogue, extraction: NoteReader())
    #expect(plan.rows.map(\.draft.ownership) == [.owned, .owned, .wanted, .wanted])
    // A wanted object has no grade; what the cell said stays as words.
    let kart = plan.rows[3].draft
    #expect(kart.values[.axis("boxCondition")] == nil)
    #expect(kart.values[.notes] == .text("Mario Kart 64 (boite endommagé)"))
  }

  @Test func aListMapsItsHeadersAndKeepsTheRestInTheNote() async throws {
    let csv = """
      Album,Artiste,Année,Pressage,Commentaire
      Kid A (signé Thom Yorke),Radiohead,2000,UK first press,"Coin un peu abîmé"
      OK Computer,Radiohead,circa 1997,,
      """
    let input = ImportInput(fileName: "Mes vinyles.csv", data: Data(csv.utf8))
    let plan = try await SpreadsheetImporter().plan(input, catalogue: Self.catalogue, extraction: NoteReader())
    #expect(plan.rows.count == 2)
    let kidA = plan.rows[0].draft
    #expect(kidA.type == "music")
    #expect(kidA.values[.title] == .text("Kid A"))
    #expect(kidA.values[.subtitle] == .text("Radiohead"))
    #expect(kidA.values[.year] == .year(2000))
    #expect(kidA.values[.field("signed")] == .entries([["by": "Thom Yorke"]]))
    // "Pressage" maps to nothing Music has, so it's kept with its header.
    #expect(kidA.values[.notes] == .text("Pressage: UK first press\nCoin un peu abîmé"))
    #expect(plan.rows[1].draft.values[.notes] == .text("Année: circa 1997"))
    #expect(plan.rows[1].line == 3)
  }
}

/// Ids for `plan`, made in order.
final class LockedCounter: @unchecked Sendable {
  private var value = 0
  private let lock = NSLock()

  func next() -> UUID {
    lock.lock()
    defer { lock.unlock() }
    value += 1
    return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
  }
}

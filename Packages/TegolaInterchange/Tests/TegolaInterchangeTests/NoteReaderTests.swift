import TegolaCatalogue
import TegolaModel
import Testing

@testable import TegolaInterchange

/// Page 49's real cells from `Jeux collection.csv`, each with its column, read without the on-device model (D-61).
@Suite struct NoteReaderTests {
  static let catalogue = try! Catalogue.bundled()

  static func read(_ text: String, subtype: String? = nil, type: TypeManifest.ID = "video-game") -> ExtractedCell {
    NoteReader().read(ImportCell(text: text, type: try! catalogue.resolve(type, subtype: subtype)))
  }

  @Test func aDamagedBoxIsGradedAndTheTitleIsAsWritten() {
    let cell = Self.read("Mario 64 (boite endommagé + cartouche)", subtype: "n64")
    #expect(cell.title == "Mario 64")
    #expect(cell.values[.field("inserts")] == .options(["box", "cart"]))
    #expect(cell.values[.axis("boxCondition")] == .text("Poor"))
    #expect(cell.values[.notes] == nil)
    #expect(cell.noticed == [.imperfect])
  }

  @Test func aCartThatDoesntBootIsImperfect() {
    let cell = Self.read("Moonwalker (cartouche ko)")
    #expect(cell.title == "Moonwalker")
    #expect(cell.values[.axis("mediaCondition")] == .text("Poor"))
    #expect(cell.values[.field("media")] == .text("Cartridge"))
    #expect(cell.noticed == [.imperfect])
  }

  @Test func whatIsntAPartStaysInTheNote() {
    let cell = Self.read("Killer instinct (manque cd audio + cale cartouche)")
    #expect(cell.title == "Killer instinct")
    #expect(cell.values[.notes] == .text("manque cd audio + cale cartouche"))
    #expect(cell.noticed == [.imperfect])
  }

  @Test func aDedicationIsASignature() {
    let cell = Self.read("Tortue ninja (cartouche dédicace JDG + manuel)")
    #expect(cell.title == "Tortue ninja")
    #expect(cell.values[.field("signed")] == .entries([["by": "JDG"]]))
    #expect(cell.values[.field("inserts")] == .options(["manual"]))
    #expect(cell.values[.field("media")] == .text("Cartridge"))
    #expect(cell.noticed == [.signed])
  }

  @Test func aSlashIsABundle() {
    let cell = Self.read("Mario / duck hunt (cartouche + manuel)")
    #expect(cell.title == "Mario / duck hunt")
    #expect(cell.works == ["Mario", "duck hunt"])
    #expect(cell.noticed == [.bundle])
    #expect(Self.read("Heavy rain / beyond 2 souls").works == ["Heavy rain", "beyond 2 souls"])
  }

  /// The file has "Fantasy zone (cartouche)" too: the doublon is this cell, the second copy.
  @Test func doublonMarksTheSecondCopy() {
    let cell = Self.read("Fantasy zone (cartouche) doublon")
    #expect(cell.title == "Fantasy zone")
    #expect(cell.noticed == [.duplicate])
  }

  @Test func digitalIsNoticedAndKeptInTheNote() {
    let cell = Self.read("It take two (digital)")
    #expect(cell.title == "It take two")
    #expect(cell.values[.notes] == .text("digital"))
    #expect(cell.noticed == [.digital])
  }

  @Test func aSubtypesPresetMediaAgreesWithTheCell() {
    let cell = Self.read("Tetris (cartouche + manuel)", subtype: "game-boy")
    #expect(cell.values[.field("inserts")] == .options(["cart", "manual"]))
    #expect(cell.values[.field("media")] == nil)
    #expect(cell.values[.notes] == nil)
  }

  @Test func neverInventsAndKeepsWhatItCantRead() {
    let cell = Self.read("Tennis (four players) (cartouche x2)")
    #expect(cell.title == "Tennis")
    #expect(cell.values[.notes] == .text("four players + cartouche x2"))
    #expect(cell.noticed.isEmpty)
    // A typo stays: matching fixes titles, never the reader.
    #expect(Self.read("Donckey Kong Country 2").title == "Donckey Kong Country 2")
    #expect(Self.read("Donckey Kong Country 2").values.isEmpty)
    #expect(Self.read("Clive barker undying )").title == "Clive barker undying )")
  }
}

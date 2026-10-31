import Foundation
import TegolaFixtures
import Testing

@testable import TegolaInterchange

@Suite struct DelimitedTextTests {
  /// The real file (page 49): 20 platform columns after an empty corner cell, 485 games.
  @Test func readsTheJeuxCollection() throws {
    let table = try DelimitedText(data: try Fixture.jeuxCollection.data())
    #expect(table.separator == ";")
    #expect(table.encoding == .utf8)
    #expect(table.header.count == 21)
    #expect(table.header.first == "")
    #expect(Array(table.header.prefix(4)) == ["", "Ps1", "Ps2", "Ps3"])
    #expect(table.header.contains("Dreamcast"))  // written "Dreamcast " in the file
    #expect(table.body.allSatisfy { $0.count == 21 })
    #expect(table.body.flatMap { $0 }.filter { !$0.isEmpty }.count == 485)
  }

  @Test(arguments: [
    ("a,b,c\n1,2,3\n", Character(",")),
    ("a;b;c\n1;2;3\n", ";"),
    ("a\tb\tc\n1\t2\t3\n", "\t"),
    ("a|b\n1|2\n", "|"),
  ])
  func guessesTheSeparator(_ text: String, _ expected: Character) throws {
    #expect(try DelimitedText(data: Data(text.utf8)).separator == expected)
  }

  @Test func aCommaInsideQuotesIsText() throws {
    let table = try DelimitedText(data: Data("title,platform\n\"Doom, boxed\",PC\n\"Say \"\"hi\"\"\",N64\n".utf8))
    #expect(table.rows == [["title", "platform"], ["Doom, boxed", "PC"], ["Say \"hi\"", "N64"]])
  }

  @Test func aQuotedCellMaySpanLines() throws {
    let table = try DelimitedText(data: Data("title;note\r\nTetris;\"cartouche\r\nmanuel\"\r\n".utf8))
    #expect(table.rows == [["title", "note"], ["Tetris", "cartouche\r\nmanuel"]])
  }

  @Test func aByteOrderMarkIsNotPartOfTheFirstHeader() throws {
    let table = try DelimitedText(data: Data([0xEF, 0xBB, 0xBF] + Array("title,year\nDoom,1993\n".utf8)))
    #expect(table.header == ["title", "year"])
  }

  @Test func utf16WithAByteOrderMarkReads() throws {
    let data = try #require("titre;année\nRidge Racer;1995\n".data(using: .utf16))
    let table = try DelimitedText(data: data)
    #expect(table.rows == [["titre", "année"], ["Ridge Racer", "1995"]])
  }

  /// An old Excel export: "boîte endommagée" in Windows-1252, not valid UTF-8.
  @Test func latinBytesStillRead() throws {
    let data = try #require("titre;note\nMario 64;bo\u{EE}te endommag\u{E9}e\n".data(using: .windowsCP1252))
    let table = try DelimitedText(data: data)
    #expect(table.rows.last == ["Mario 64", "boîte endommagée"])
  }

  @Test func anUnterminatedQuoteSaysWhereItOpened() {
    #expect(throws: DelimitedTextError.unterminatedQuote(line: 2)) {
      try DelimitedText(data: Data("title;note\nTetris;\"cartouche\nmanuel\nDoom;ok\n".utf8))
    }
  }

  @Test func spacesAroundAQuotedCellAreDropped() throws {
    let table = try DelimitedText(data: Data("title;platform\n \"Doom\" ;PC\n".utf8))
    #expect(table.rows == [["title", "platform"], ["Doom", "PC"]])
  }

  @Test func aLineHoldingOnlyAnEmptyQuotedCellIsARow() throws {
    let table = try DelimitedText(data: Data("title\n\"\"\n\nDoom\n".utf8))
    #expect(table.rows == [["title"], [""], ["Doom"]])
  }

  @Test func raggedRowsStayRagged() throws {
    let table = try DelimitedText(data: Data("a,b,c\n1,2\n1,2,3,4\n".utf8))
    #expect(table.rows.map(\.count) == [3, 2, 4])
  }
}

import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

@Suite struct SearchTests {
  func shelf() throws -> (Harness, kidA: ObjectID, silvergun: ObjectID) {
    var harness = Harness()
    let kidA = try harness.add(
      "music",
      "Kid A",
      subtype: "vinyl",
      values: [
        .subtitle: .text("Radiohead"),
        .field("tracklist"): .entries([
          ["position": "A1", "title": "Everything in Its Right Place"], ["position": "A2", "title": "Kid A"],
          ["position": "B1", "title": "Idioteque"],
        ]),
      ]
    )
    let silvergun = try harness.add(
      subtype: "saturn",
      values: [.field("publisher"): .text("Treasure"), .axis("boxCondition"): .text("Poor")]
    )
    try harness.perform(.setPlace([silvergun], PlacePath(typed: "Office › Shelf 2")))
    return (harness, kidA, silvergun)
  }

  /// F11's done-when: a single track on an LP is found, and the result says it matched the tracklist.
  @Test func findsASingleTrackOnAnLP() throws {
    let (harness, kidA, _) = try shelf()
    let hits = search(SearchQuery(text: "idioteque"), in: harness.shelf, catalogue: Harness.catalogue)
    #expect(hits.map(\.object) == [kidA])
    #expect(hits.first?.matched == ["Tracklist"])
  }

  @Test func everyWordMustMatchSomewhereAndAccentsDontMatter() throws {
    var (harness, kidA, silvergun) = try shelf()
    #expect(
      search(SearchQuery(text: "radiohead idioteque"), in: harness.shelf, catalogue: Harness.catalogue).map(\.object)
        == [kidA]
    )
    #expect(search(SearchQuery(text: "radiohead treasure"), in: harness.shelf, catalogue: Harness.catalogue).isEmpty)
    let bjork = try harness.add("music", "Homogenic", values: [.subtitle: .text("Björk")])
    #expect(
      search(SearchQuery(text: "bjork"), in: harness.shelf, catalogue: Harness.catalogue).map(\.object) == [bjork]
    )
    // The place and the subtype are searchable too.
    #expect(
      search(SearchQuery(text: "shelf 2"), in: harness.shelf, catalogue: Harness.catalogue).map(\.object) == [silvergun]
    )
    #expect(
      search(SearchQuery(text: "saturn"), in: harness.shelf, catalogue: Harness.catalogue).map(\.object) == [silvergun]
    )
  }

  /// The status chip filters on derived statuses: a due cartridge is the only *watch*.
  @Test func theStatusChipFiltersOnDerivedStatuses() throws {
    var (harness, _, _) = try shelf()
    let due = try SaveBatteryClockTests.cartridge(&harness, year: 1994)
    let statuses = ShelfSignals(
      shelf: harness.shelf,
      catalogue: Harness.catalogue,
      now: harness.clock,
      calendar: .utc
    ).statuses
    let watch = search(SearchQuery(status: .watch), in: harness.shelf, catalogue: Harness.catalogue, statuses: statuses)
    #expect(watch.map(\.object) == [due])
    #expect(!SearchQuery(status: .watch).isEmpty)
    let fine = search(SearchQuery(status: .fine), in: harness.shelf, catalogue: Harness.catalogue, statuses: statuses)
    #expect(fine.count == 2)
  }

  @Test func filtersStack() throws {
    var (harness, kidA, silvergun) = try shelf()
    try harness.perform(.lend(kidA, to: .new(name: "Max"), due: nil, note: ""))
    let catalogue = Harness.catalogue
    #expect(search(SearchQuery(types: ["music"]), in: harness.shelf, catalogue: catalogue).map(\.object) == [kidA])
    #expect(search(SearchQuery(lentOut: true), in: harness.shelf, catalogue: catalogue).map(\.object) == [kidA])
    #expect(search(SearchQuery(types: ["video-game"], lentOut: true), in: harness.shelf, catalogue: catalogue).isEmpty)
    let office = try #require(harness.shelf.places.values.first { $0.name == "Office" })
    #expect(search(SearchQuery(place: office.id), in: harness.shelf, catalogue: catalogue).map(\.object) == [silvergun])
  }

  /// Review of M3, finding 8: the archive chip alone is a query.
  @Test func theArchiveChipAloneIsAQuery() {
    #expect(!SearchQuery(includeArchive: true).isEmpty)
  }

  @Test func theArchiveAnswersDidIEverOwnThis() throws {
    var (harness, _, silvergun) = try shelf()
    try harness.perform(.letGo(silvergun, .sold(price: nil)))
    let catalogue = Harness.catalogue
    #expect(search(SearchQuery(text: "silvergun"), in: harness.shelf, catalogue: catalogue).isEmpty)
    #expect(
      search(SearchQuery(text: "silvergun", includeArchive: true), in: harness.shelf, catalogue: catalogue).map(
        \.object
      )
        == [silvergun]
    )
  }

  /// F11's done-when: Imperfect lists exactly the objects with a missing or worn part.
  @Test func imperfectListsMissingOrWornParts() throws {
    var (harness, _, silvergun) = try shelf()
    _ = try harness.add("video-game", "Guardian Heroes", values: [.axis("boxCondition"): .text("Near mint")])
    let missing = try harness.add(
      "video-game",
      "Shining Force III",
      values: [.axis("manualCondition"): .text("Missing")]
    )
    let hits = search(SearchQuery(view: .imperfect), in: harness.shelf, catalogue: Harness.catalogue)
    #expect(Set(hits.map(\.object)) == [silvergun, missing])
  }

  @Test func savedViewsForDuplicatesSignedAndMightLetGo() throws {
    var (harness, kidA, _) = try shelf()
    let second = try harness.add("music", "Kid A", subtype: "vinyl")
    _ = try harness.add("music", "Kid A", subtype: "cd")
    let signed = try harness.add("music", "Amnesiac", values: [.field("signed"): .entries([["by": "Thom Yorke"]])])
    try harness.perform(.setMightLetGo(kidA, true))
    let catalogue = Harness.catalogue
    #expect(
      Set(search(SearchQuery(view: .duplicates), in: harness.shelf, catalogue: catalogue).map(\.object)) == [
        kidA, second,
      ]
    )
    #expect(search(SearchQuery(view: .signed), in: harness.shelf, catalogue: catalogue).map(\.object) == [signed])
    #expect(search(SearchQuery(view: .mightLetGo), in: harness.shelf, catalogue: catalogue).map(\.object) == [kidA])
  }
}

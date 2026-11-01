import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

@Suite struct LookAlikeTests {
  static func draft(_ title: String, subtype: String? = "n64", publisher: String? = nil) -> ObjectDraft {
    var values: [FieldKey: FieldValue] = [.title: .text(title)]
    if let publisher { values[.field("publisher")] = .text(publisher) }
    return ObjectDraft(type: "video-game", subtype: subtype, values: values)
  }

  @Test func neverMergesAndOffersThreeChoices() throws {
    var harness = Harness()
    let mario = try harness.add(
      "video-game",
      "Mario Kart 64",
      subtype: "n64",
      values: [.field("publisher"): .text("Nintendo")]
    )
    let pal = try harness.add("video-game", "Mario Kart 64", subtype: nil)
    let wanted = try harness.add("video-game", "Mario Kart 64", subtype: "n64", ownership: .wanted)
    let zelda = try harness.add(
      "video-game",
      "Zelda Ocarina of Time",
      subtype: "n64",
      values: [.field("publisher"): .text("nintendo")]
    )
    _ = try harness.add("video-game", "Doom", subtype: "n64", values: [.field("publisher"): .text("GT Interactive")])

    let draft = Self.draft("  mario kart 64", publisher: "Nintendo")
    let lookAlikes = LookAlikes(draft, shelf: harness.shelf, catalogue: Harness.catalogue)
    #expect(lookAlikes.owned == [mario])
    #expect(lookAlikes.otherPrints == [pal])
    #expect(lookAlikes.wanted == [wanted])
    #expect(lookAlikes.related == [zelda])
    #expect(lookAlikes.asks)
    #expect(lookAlikes.choices == [.open(mario), .anotherCopy(mario), .addAsNew])

    // No choice merges: opening writes nothing, and a row's other copy is a new object beside it.
    let collection = try #require(harness.shelf.objects[mario]?.collectionID)
    #expect(
      lookAlikes.command(for: .open(mario), adding: draft, to: .new(name: "x"), origin: .typed, shelf: harness.shelf)
        == nil
    )
    #expect(
      lookAlikes.command(
        for: .anotherCopy(mario),
        adding: draft,
        to: .new(name: "x"),
        origin: .typed,
        shelf: harness.shelf
      )
        == .add(draft, to: .existing(collection), origin: .typed)
    )
    let count = harness.shelf.objects.count
    try harness.perform(
      try #require(
        lookAlikes.command(
          for: .addAsNew,
          adding: draft,
          to: .existing(collection),
          origin: .typed,
          shelf: harness.shelf
        )
      )
    )
    #expect(harness.shelf.objects.count == count + 1 && harness.shelf.objects[mario] != nil)
  }

  @Test func asksOnlyWhenUnsure() throws {
    var harness = Harness()
    _ = try harness.add("video-game", "Mario Kart 64", subtype: nil)
    let lookAlikes = LookAlikes(Self.draft("Mario Kart 64"), shelf: harness.shelf, catalogue: Harness.catalogue)
    #expect(!lookAlikes.asks && lookAlikes.otherPrints.count == 1)
    #expect(lookAlikes.choices == [.addAsNew])
    #expect(LookAlikes(Self.draft(""), shelf: harness.shelf, catalogue: Harness.catalogue).otherPrints.isEmpty)
  }

  @Test func anotherCopyOfACountRaisesIt() throws {
    var harness = Harness()
    let cable = try harness.add("thing", "Câble péritel", bulk: .quantity, quantity: 2)
    let draft = ObjectDraft(type: "thing", values: [.title: .text("câble PÉRITEL")], bulk: .quantity)
    let lookAlikes = LookAlikes(draft, shelf: harness.shelf, catalogue: Harness.catalogue)
    #expect(lookAlikes.owned == [cable])
    let command = lookAlikes.command(
      for: .anotherCopy(cable),
      adding: draft,
      to: .new(name: "x"),
      origin: .typed,
      shelf: harness.shelf
    )
    #expect(command == .adjustQuantity(cable, by: 1))
  }

  @Test func onlyAnAmbiguousMatchAsks() {
    let candidate = LookupCandidate(
      releaseID: "t",
      type: "video-game",
      values: [:],
      confidence: 0.5,
      reasons: [.title],
      sources: [.init(name: "IGDB")]
    )
    #expect(MatchOutcome.ambiguous([candidate, candidate]).asks)
    #expect(!MatchOutcome.matched(candidate).asks && !MatchOutcome.unknown.asks)
  }
}

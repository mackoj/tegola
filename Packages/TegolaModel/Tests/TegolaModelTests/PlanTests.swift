import Foundation
import TegolaCatalogue
import TegolaModelTesting
import Testing

@testable import TegolaModel

/// A shelf with a log, driven the way `ShelfClient.perform` drives it: plan, then apply.
struct Harness {
  static let catalogue = try! Catalogue.bundled()
  static let start = Date(timeIntervalSince1970: 1_800_000_000)

  var shelf = Shelf()
  var log: [ShelfEvent] = []
  let ids = Counter()
  var clock = Harness.start

  func context(_ source: ShelfEvent.Source = .collector) -> PlanContext {
    let ids = ids
    return PlanContext(at: clock, source: source, catalogue: Self.catalogue, makeID: { ids.next() })
  }

  @discardableResult
  mutating func perform(_ command: ShelfCommand, as source: ShelfEvent.Source = .collector) throws(ShelfRuleViolation)
    -> [ShelfEvent]
  {
    let events = try plan(command, on: shelf, context: context(source))
    shelf = apply(events, to: shelf)
    log += events
    clock += 60
    return events
  }

  /// Adds an object typed by the collector and returns its id.
  mutating func add(
    _ type: TypeManifest.ID = "video-game",
    _ title: String = "Radiant Silvergun",
    subtype: String? = nil,
    values: [FieldKey: FieldValue] = [:],
    ownership: ShelfObject.Ownership = .owned,
    bulk: ShelfObject.Bulk? = nil,
    quantity: Int = 1,
    origin: AddOrigin = .typed
  ) throws -> ObjectID {
    var values = values
    values[.title] = .text(title)
    let draft = ObjectDraft(
      type: type,
      subtype: subtype,
      values: values,
      ownership: ownership,
      bulk: bulk,
      quantity: quantity
    )
    let collection = shelf.collections.values.first { $0.typeID == type }.map { CollectionChoice.existing($0.id) }
    let source: ShelfEvent.Source =
      switch origin {
      case .typed, .firstPiece: .collector
      case .captured: .capture
      case .imported: .import
      }
    let events = try perform(
      .add(draft, to: collection ?? .new(name: "My \(type.rawValue)"), origin: origin),
      as: source
    )
    return try #require(events.compactMap { if case .added(let object, _) = $0.kind { object.id } else { nil } }.first)
  }
}

@Suite struct PlanTests {
  @Test func addingToANewCollectionMakesItFirst() throws {
    var harness = Harness()
    let id = try harness.add(subtype: "saturn", values: [.field("region"): .text("NTSC-J")])
    #expect(harness.log.count == 2)
    #expect(harness.log.map(\.seq) == [1, 2])
    let object = try #require(harness.shelf.objects[id])
    #expect(object.identity == .confirmed)
    #expect(object.subtype == "saturn")
    #expect(harness.shelf.collections[object.collectionID]?.typeID == "video-game")
  }

  @Test func aCaptureIsAGuessUntilTheCollectorConfirms() throws {
    var harness = Harness()
    let id = try harness.add(origin: .captured)
    #expect(harness.shelf.objects[id]?.identity == .unconfirmed)
    #expect(throws: ShelfRuleViolation.collectorOnly) { try harness.perform(.confirm([id]), as: .lookup) }
    try harness.perform(.confirm([id]))
    #expect(harness.shelf.objects[id]?.identity == .confirmed)
    #expect(try harness.perform(.confirm([id])).isEmpty)
  }

  @Test func aPhotoWithNothingIdentifiedNeedsDetails() throws {
    var harness = Harness()
    let draft = ObjectDraft(type: "thing", needsDetails: true)
    try harness.perform(.add(draft, to: .new(name: "Things"), origin: .captured), as: .capture)
    let object = try #require(harness.shelf.objects.values.first)
    #expect(object.identity == .needsDetails)
    #expect(throws: ShelfRuleViolation.emptyTitle) { try harness.perform(.confirm([object.id])) }
  }

  @Test func everyObjectNeedsATitle() throws {
    var harness = Harness()
    #expect(throws: ShelfRuleViolation.emptyTitle) { try harness.add("video-game", "  ") }
  }

  @Test func unknownTypesSubtypesAndFieldsAreRefused() throws {
    var harness = Harness()
    #expect(throws: ShelfRuleViolation.unknownType("dreamcast")) { try harness.add("dreamcast") }
    #expect(throws: ShelfRuleViolation.unknownSubtype("video-game", "dreamcast")) {
      try harness.add(subtype: "dreamcast")
    }
    #expect(throws: ShelfRuleViolation.unknownField(.field("spineCard"))) {
      try harness.add(values: [.field("spineCard"): .flag(true)])
    }
    // Saturn adds the spine card, and every type inherits the item level.
    _ = try harness.add(subtype: "saturn", values: [.field("spineCard"): .flag(true)])
    _ = try harness.add(values: [.field("signed"): .entries([["by": "JDG"]])])
    #expect(throws: ShelfRuleViolation.unknownField(.axis("region"))) {
      try harness.add(values: [.axis("region"): .text("Good")])
    }
  }

  @Test func editKeepsTheChangedKeysOnly() throws {
    var harness = Harness()
    let id = try harness.add(values: [.field("region"): .text("NTSC-J"), .notes: .text("From Akihabara")])
    let events = try harness.perform(
      .edit(id, values: [.title: .text("Radiant Silvergun"), .field("region"): .text("PAL"), .notes: nil])
    )
    #expect(events.map(\.kind) == [.edited(id, changes: [.field("region"): .text("PAL"), .notes: nil])])
    #expect(harness.shelf.objects[id]?.values[.notes] == nil)
    #expect(try harness.perform(.edit(id, values: [.field("region"): .text("PAL")])).isEmpty)
    #expect(throws: ShelfRuleViolation.collectorOnly) {
      try harness.perform(.edit(id, values: [.notes: .text("x")]), as: .lookup)
    }
  }

  @Test func aLookupNeverOverwritesWhatTheCollectorTyped() throws {
    var harness = Harness()
    let id = try harness.add(values: [.field("publisher"): .text("Treasure")])
    try harness.perform(
      .applyLookup(id, values: [.field("publisher"): .text("ESP"), .year: .year(1998)]),
      as: .lookup
    )
    let object = try #require(harness.shelf.objects[id])
    #expect(object.values[.field("publisher")] == .text("Treasure"))
    #expect(object.values[.year] == .year(1998))
    #expect(object.auto == [.year])
    // A key it filled can be filled again, until the collector touches it.
    try harness.perform(.applyLookup(id, values: [.year: .year(1999)]), as: .lookup)
    #expect(harness.shelf.objects[id]?.values[.year] == .year(1999))
    try harness.perform(.edit(id, values: [.year: .year(1998)]))
    #expect(harness.shelf.objects[id]?.auto == [])
    #expect(try harness.perform(.applyLookup(id, values: [.year: .year(2000)]), as: .lookup).isEmpty)
  }

  @Test func aWantedObjectHasNoCondition() throws {
    var harness = Harness()
    #expect(throws: ShelfRuleViolation.wantedHasNoCondition) {
      try harness.add(values: [.condition: .text("Mint")], ownership: .wanted)
    }
    let id = try harness.add(ownership: .wanted)
    #expect(throws: ShelfRuleViolation.wantedHasNoCondition) {
      try harness.perform(.edit(id, values: [.axis("boxCondition"): .text("Good")]))
    }
    #expect(harness.shelf.objects[id]?.counts == false)
  }

  @Test func lendingFollowsTheRules() throws {
    var harness = Harness()
    let id = try harness.add()
    try harness.perform(.lend(id, to: .new(name: "Max"), due: nil, note: ""))
    let loan = try #require(harness.shelf.openLoan(on: id))
    #expect(harness.shelf.persons[loan.personID]?.name == "Max")
    #expect(throws: ShelfRuleViolation.alreadyOnLoan) {
      try harness.perform(.lend(id, to: .existing(loan.personID), due: nil, note: ""))
    }
    #expect(throws: ShelfRuleViolation.alreadyOnLoan) { try harness.perform(.letGo(id, .gifted)) }
    try harness.perform(.returnLoan(loan.id, cameBack: .damaged, condition: "  Sleeve torn  "))
    let closed = try #require(harness.shelf.loans[loan.id])
    #expect(closed.closedBy == .collector)
    #expect(closed.isOneSided)
    #expect(closed.cameBack == .damaged)
    #expect(closed.returnCondition == "Sleeve torn")
    #expect(throws: ShelfRuleViolation.notOnLoan) { try harness.perform(.returnLoan(loan.id, condition: nil)) }
    try harness.perform(.letGo(id, .sold(price: nil)))
    #expect(throws: ShelfRuleViolation.alreadyLetGo) {
      try harness.perform(.lend(id, to: .existing(loan.personID), due: nil, note: ""))
    }
    let wanted = try harness.add(ownership: .wanted)
    #expect(throws: ShelfRuleViolation.notOwned) {
      try harness.perform(.lend(wanted, to: .existing(loan.personID), due: nil, note: ""))
    }
  }

  /// Promise 6 (PD-020, PD-121). Thing asks how duplicates count, so it can be a count.
  @Test func aCountCantBeLentButAPromotedCopyCan() throws {
    var harness = Harness()
    try checkPromotion(&harness, try harness.add("thing", "Meeples", bulk: .quantity, quantity: 3))
  }

  func checkPromotion(_ harness: inout Harness, _ id: ObjectID) throws {
    #expect(throws: ShelfRuleViolation.quantityCantBeLent) {
      try harness.perform(.lend(id, to: .new(name: "Max"), due: nil, note: ""))
    }
    let events = try harness.perform(.promote(id))
    guard case .promoted(_, let copy) = try #require(events.first).kind else {
      Issue.record("not a promotion")
      return
    }
    #expect(copy.bulk == .rows)
    #expect(copy.promotedFrom == id)
    #expect(harness.shelf.objects[id]?.quantity == 2)
    try harness.perform(.lend(copy.id, to: .new(name: "Max"), due: nil, note: ""))
  }

  @Test func rowsAreOneCopyEach() throws {
    var harness = Harness()
    #expect(throws: ShelfRuleViolation.rowsAreOneCopy) { try harness.add(quantity: 2) }
    let id = try harness.add()
    #expect(throws: ShelfRuleViolation.notAQuantity) { try harness.perform(.adjustQuantity(id, by: 1)) }
  }

  @Test func quantitiesNeverGoBelowZero() throws {
    var harness = Harness()
    let id = try harness.add("thing", "Meeples", bulk: .quantity, quantity: 2)
    #expect(throws: ShelfRuleViolation.quantityBelowZero) { try harness.perform(.adjustQuantity(id, by: -3)) }
    try harness.perform(.adjustQuantity(id, by: -2))
    #expect(harness.shelf.objects[id]?.quantity == 0)
  }

  @Test func typingAPlaceMakesTheNestedPlacesOnce() throws {
    var harness = Harness()
    let first = try harness.add()
    let second = try harness.add("video-game", "Guardian Heroes")
    try harness.perform(.setPlace([first], PlacePath(typed: "Office › Shelf 2")))
    try harness.perform(.setPlace([second], PlacePath(typed: "office > shelf 2")))
    #expect(harness.shelf.places.count == 2)
    #expect(harness.shelf.objects[first]?.placeID == harness.shelf.objects[second]?.placeID)
    try harness.perform(.setPlace([first], nil))
    #expect(harness.shelf.objects[first]?.placeID == nil)
  }

  /// Story 109: near-duplicate places are offered for merging, and a merge keeps everything.
  @Test func nearDuplicatePlacesMergeIntoTheOneKept() throws {
    var harness = Harness()
    let first = try harness.add()
    let second = try harness.add("video-game", "Guardian Heroes")
    try harness.perform(.setPlace([first], PlacePath(typed: "Living room › Shelf 1")))
    try harness.perform(.setPlace([second], PlacePath(typed: "Livng room")))
    let pairs = harness.shelf.nearDuplicatePlaces()
    #expect(pairs.map { [$0.0.name, $0.1.name] } == [["Living room", "Livng room"]])
    let (kept, typo) = (pairs[0].0, pairs[0].1)
    let events = try harness.perform(.mergePlaces(typo.id, into: kept.id))
    #expect(events.map(\.kind.name) == ["placed", "placesMerged"])
    #expect(harness.shelf.objects[second]?.placeID == kept.id)
    #expect(harness.shelf.places[typo.id]?.mergedInto == kept.id)
    #expect(harness.shelf.livePlaces.count == 2)
    #expect(harness.shelf.nearDuplicatePlaces().isEmpty)
    // Typing the typo again makes a new place: merged places are out of every list.
    try harness.perform(.setPlace([second], PlacePath(typed: "Livng room")))
    #expect(harness.shelf.livePlaces.count == 3)
  }

  @Test func aPlaceCantMergeIntoItselfOrWhatsInsideIt() throws {
    var harness = Harness()
    let id = try harness.add()
    try harness.perform(.setPlace([id], PlacePath(typed: "Office › Shelf 2")))
    let office = try #require(harness.shelf.places.values.first { $0.name == "Office" })
    let shelf = try #require(harness.shelf.places.values.first { $0.name == "Shelf 2" })
    #expect(throws: ShelfRuleViolation.mergeIntoItself) { try harness.perform(.mergePlaces(office.id, into: shelf.id)) }
    #expect(throws: ShelfRuleViolation.mergeIntoItself) {
      try harness.perform(.mergePlaces(office.id, into: office.id))
    }
  }

  @Test func aTypedCollectionTakesOnlyItsType() throws {
    var harness = Harness()
    let game = try harness.add()
    let music = try harness.add("music", "Kid A")
    let musicCollection = try #require(harness.shelf.objects[music]?.collectionID)
    #expect(throws: ShelfRuleViolation.wrongType(collection: musicCollection, type: "video-game")) {
      try harness.perform(.moveObjects([game], to: musicCollection))
    }
    try harness.perform(.createCollection(name: "Everything", type: nil))
    let mixed = try #require(harness.shelf.collections.values.first { $0.typeID == nil })
    try harness.perform(.moveObjects([game, music], to: mixed.id))
    #expect(harness.shelf.objects.values.allSatisfy { $0.collectionID == mixed.id })
  }

  @Test func borrowingAndGivingBack() throws {
    var harness = Harness()
    let own = try harness.add()
    #expect(throws: ShelfRuleViolation.notBorrowed) { try harness.perform(.markBorrowed(own, from: .new(name: "Léa"))) }
    let id = try harness.add(ownership: .borrowed)
    try harness.perform(.markBorrowed(id, from: .new(name: "Léa")))
    #expect(harness.shelf.objects[id]?.ownership == .borrowed)
    #expect(harness.shelf.objects[id]?.counts == false)
    #expect(throws: ShelfRuleViolation.alreadyOnLoan) { try harness.perform(.setOwned(id)) }
    try harness.perform(.giveBack(id))
    #expect(harness.shelf.openLoan(on: id) == nil)
  }

  /// Review of M2, finding 3: a grade goes through its ladder axis, so a wanted object can't get one by another key.
  @Test func aScaleIsGradedOnlyThroughItsAxis() throws {
    var harness = Harness()
    #expect(throws: ShelfRuleViolation.unknownField(.field("mediaCondition"))) {
      try harness.add(values: [.field("mediaCondition"): .text("Mint")], ownership: .wanted)
    }
  }

  /// Review of M2, finding 4: a lookup never writes acquired, money or a grade, nor an empty title.
  @Test func aLookupLeavesTheCollectorsKeysAlone() throws {
    var harness = Harness()
    let id = try harness.add(ownership: .wanted)
    let euro = try #require(Currency("EUR"))
    let events = try harness.perform(
      .applyLookup(
        id,
        values: [
          .acquired: .date(Harness.start), .paid: .money(Money(minorUnits: 100, currency: euro)),
          .condition: .text("Mint"), .axis("boxCondition"): .text("Good"), .title: .text(""),
        ]
      ),
      as: .lookup
    )
    #expect(events.isEmpty)
  }

  /// Review of M2, finding 5: clearing a value is the collector's decision too.
  @Test func aClearedKeyStaysCleared() throws {
    var harness = Harness()
    let id = try harness.add(values: [.year: .year(1998)])
    try harness.perform(.edit(id, values: [.year: nil]))
    #expect(try harness.perform(.applyLookup(id, values: [.year: .year(1999)]), as: .lookup).isEmpty)
    #expect(harness.shelf.objects[id]?.values[.year] == nil)
  }

  /// Review of M2, finding 6: an origin must come from its source, so nothing else can claim to be the collector.
  @Test func anOriginMustComeFromItsSource() throws {
    var harness = Harness()
    let draft = ObjectDraft(type: "thing", values: [.title: .text("Robot")])
    for (origin, source) in [
      (AddOrigin.typed, ShelfEvent.Source.lookup), (.typed, .capture), (.captured, .collector), (.imported, .collector),
    ] {
      #expect(throws: ShelfRuleViolation.originMismatch) {
        try harness.perform(.add(draft, to: .new(name: "Things"), origin: origin), as: source)
      }
    }
  }

  @Test func whenAWantedObjectArrivesItsHuntEnds() throws {
    var harness = Harness()
    let id = try harness.add(ownership: .wanted)
    try harness.perform(.setWanted(id, priority: 1, priceCap: nil))
    try harness.perform(.setOwned(id))
    #expect(harness.shelf.objects[id]?.priority == nil)
    #expect(harness.shelf.objects[id]?.counts == true)
  }

  /// D-40: a value must fit its field.
  @Test func valuesMustFitTheirField() throws {
    var harness = Harness()
    #expect(throws: ShelfRuleViolation.invalidValue(.field("region"))) {
      try harness.add(values: [.field("region"): .text("Mars")])
    }
    #expect(throws: ShelfRuleViolation.invalidValue(.field("region"))) {
      try harness.add(values: [.field("region"): .flag(true)])
    }
    #expect(throws: ShelfRuleViolation.invalidValue(.year)) { try harness.add(values: [.year: .text("1998")]) }
    #expect(throws: ShelfRuleViolation.invalidValue(.axis("boxCondition"))) {
      try harness.add(values: [.axis("boxCondition"): .text("Shiny")])
    }
    // Saturn narrows the region to three: PAL fits, Region-free doesn't.
    _ = try harness.add(subtype: "saturn", values: [.field("region"): .text("PAL")])
    #expect(throws: ShelfRuleViolation.invalidValue(.field("region"))) {
      try harness.add(subtype: "saturn", values: [.field("region"): .text("Region-free")])
    }
    let id = try harness.add()
    #expect(throws: ShelfRuleViolation.invalidValue(.field("inserts"))) {
      try harness.perform(.edit(id, values: [.field("inserts"): .options(["map"])]))
    }
  }

  /// Review of M3, finding 2: Missing is a ladder step only where the type allows it.
  @Test func missingIsAStepOnlyWhereTheTypeAllowsIt() throws {
    var harness = Harness()
    _ = try harness.add(values: [.axis("boxCondition"): .text("Missing")])
    let board = try Harness.catalogue.resolve("board-games", subtype: nil)
    #expect(!board.allowMissing)
    #expect(board.ladderSteps == board.conditions)
  }

  /// Review of M3, findings 5 and 14: an empty entry records nothing, and a lookup drops a value that doesn't fit.
  @Test func emptyEntriesAreNoValueAndALookupDropsWhatDoesntFit() throws {
    var harness = Harness()
    let id = try harness.add(values: [.field("signed"): .entries([[:], ["by": "  "]])])
    #expect(harness.shelf.objects[id]?.values[.field("signed")] == nil)
    try harness.perform(.edit(id, values: [.field("signed"): .entries([[:]])]))
    #expect(harness.shelf.objects[id]?.values[.field("signed")] == nil)
    let events = try harness.perform(
      .applyLookup(id, values: [.field("region"): .text("Mars"), .field("publisher"): .text("Treasure")]),
      as: .lookup
    )
    #expect(events.count == 1)
    #expect(harness.shelf.objects[id]?.values[.field("publisher")] == .text("Treasure"))
  }

  /// D-34: a subtype's preset fills its field on add, and nobody sets a hidden field by hand.
  @Test func presetsFillOnAddAndHiddenFieldsStayHidden() throws {
    var harness = Harness()
    let id = try harness.add(subtype: "saturn")
    #expect(harness.shelf.objects[id]?.values[.field("media")] == .text("Optical disc"))
    #expect(harness.shelf.objects[id]?.values[.field("platform")] == .text("Sega Saturn"))
    #expect(throws: ShelfRuleViolation.hiddenField(.field("media"))) {
      try harness.perform(.edit(id, values: [.field("media"): .text("Cartridge")]))
    }
    #expect(throws: ShelfRuleViolation.hiddenField(.field("platform"))) {
      try harness.add(subtype: "saturn", values: [.field("platform"): .text("Dreamcast")])
    }
    #expect(
      try harness.perform(.applyLookup(id, values: [.field("platform"): .text("Dreamcast")]), as: .lookup).isEmpty
    )
  }

  @Test func theSameCommandOnTheSameShelfPlansTheSameEvents() throws {
    var first = Harness()
    var second = Harness()
    _ = try first.add(subtype: "saturn")
    _ = try second.add(subtype: "saturn")
    #expect(first.log == second.log)
  }
}

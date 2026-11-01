import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

@Suite struct ImportBatchTests {
  static func game(_ title: String, subtype: String? = nil) -> ObjectDraft {
    ObjectDraft(type: "video-game", subtype: subtype, values: [.title: .text(title)])
  }

  static let jeux = ImportBatch(
    importer: "spreadsheet",
    fileName: "Jeux collection.csv",
    collectionName: "Jeux",
    rows: [game("Tetris", subtype: "game-boy"), game("Mario 64", subtype: "n64"), game("Doom")]
  )

  @discardableResult
  static func importJeux(_ harness: inout Harness) throws -> [ObjectID] {
    let events = try harness.perform(.importBatch(jeux), as: .import)
    return events.compactMap { if case .added(let object, _) = $0.kind { object.id } else { nil } }
  }

  @Test func landsInOneNewCollectionUnconfirmedAndInOneBatch() throws {
    var harness = Harness()
    let events = try harness.perform(.importBatch(Self.jeux), as: .import)
    let batchID = try #require(events.first?.batchID)
    #expect(events.allSatisfy { $0.batchID == batchID })
    #expect(events.map(\.kind.name) == ["collectionCreated", "batchImported", "added", "added", "added"])
    #expect(harness.shelf.collections.count == 1)
    let collection = try #require(harness.shelf.collections.values.first)
    #expect(collection.name == "Jeux")
    #expect(collection.typeID == "video-game")
    let record = try #require(harness.shelf.batches[batchID])
    #expect(record.rowCount == 3 && record.fileName == "Jeux collection.csv" && record.collectionID == collection.id)
    for object in harness.shelf.objects.values {
      // Nothing an import writes is confirmed (PD-042, PD-047), and it never writes `acquired` (D-14).
      #expect(object.identity == .unconfirmed)
      #expect(object.acquiredAt == nil)
      #expect(object.collectionID == collection.id)
      #expect(object.imported == ImportMark(batchID: batchID, touched: false))
    }
  }

  @Test func aMixedListMakesAMixedCollection() throws {
    var harness = Harness()
    var batch = Self.jeux
    batch.rows.append(ObjectDraft(type: "thing", values: [.title: .text("Manette")]))
    try harness.perform(.importBatch(batch), as: .import)
    #expect(harness.shelf.collections.values.first?.typeID == nil)
  }

  @Test func onlyAnImportImportsAndNeverAnEmptyList() throws {
    var harness = Harness()
    #expect(throws: ShelfRuleViolation.originMismatch) { try harness.perform(.importBatch(Self.jeux)) }
    var empty = Self.jeux
    empty.rows = []
    #expect(throws: ShelfRuleViolation.emptyBatch) { try harness.perform(.importBatch(empty), as: .import) }
    // A refused row refuses the whole batch: nothing is half-imported.
    var bad = Self.jeux
    bad.rows.append(ObjectDraft(type: "video-game", values: [:]))
    #expect(throws: ShelfRuleViolation.emptyTitle) { try harness.perform(.importBatch(bad), as: .import) }
    #expect(harness.shelf == Shelf())
  }

  @Test func undoRemovesWhatNobodyTouchedAndKeepsTheRest() throws {
    var harness = Harness()
    let ids = try Self.importJeux(&harness)
    let batchID = try #require(harness.shelf.objects[ids[0]]?.imported?.batchID)
    // A lookup's answer isn't the collector's work; an edit, a photo and a confirmation are (D-12).
    try harness.perform(.applyLookup(ids[0], values: [.field("publisher"): .text("Nintendo")]), as: .lookup)
    try harness.perform(.edit(ids[1], values: [.notes: .text("boite endommagé")]))
    try harness.perform(.confirm([ids[2]]))
    #expect(harness.shelf.objects[ids[0]]?.imported?.touched == false)
    #expect(harness.shelf.objects[ids[1]]?.imported?.touched == true)

    let events = try harness.perform(.undoBatch(batchID))
    #expect(events.map(\.kind) == [.batchUndone(batchID, removed: [ids[0]], kept: [ids[1], ids[2]].sorted())])
    #expect(events.first?.batchID == batchID)
    #expect(harness.shelf.objects[ids[0]] == nil)
    #expect(harness.shelf.objects[ids[1]] != nil && harness.shelf.objects[ids[2]] != nil)
    #expect(harness.shelf.collections.count == 1)
    #expect(harness.shelf.batches[batchID]?.undoneAt != nil)
    // Undone once is undone.
    #expect(throws: ShelfRuleViolation.cantUndoBatch(batchID)) { try harness.perform(.undoBatch(batchID)) }
    // The log still holds every row: history only appends.
    #expect(harness.log.filter { $0.objectID == ids[0] }.count == 2)
    #expect(apply(harness.log, to: Shelf()) == harness.shelf)
  }

  @Test func undoingAnUntouchedImportLeavesNoEmptyCollection() throws {
    var harness = Harness()
    let ids = try Self.importJeux(&harness)
    let batchID = try #require(harness.shelf.objects[ids[0]]?.imported?.batchID)
    try harness.perform(.undoBatch(batchID))
    #expect(harness.shelf.objects.isEmpty)
    #expect(harness.shelf.collections.isEmpty)
    #expect(harness.shelf.batches[batchID] != nil)
  }

  @Test func undoIsTheCollectorsAndLastsThirtyDays() throws {
    var harness = Harness()
    let ids = try Self.importJeux(&harness)
    let batchID = try #require(harness.shelf.objects[ids[0]]?.imported?.batchID)
    #expect(throws: ShelfRuleViolation.collectorOnly) { try harness.perform(.undoBatch(batchID), as: .import) }
    let stranger = BatchID(UUID(uuidString: "00000000-0000-0000-0000-00000000BA7C")!)
    #expect(throws: ShelfRuleViolation.unknownBatch(stranger)) { try harness.perform(.undoBatch(stranger)) }
    harness.clock = Harness.start + ImportBatchRecord.undoWindow
    #expect(throws: ShelfRuleViolation.cantUndoBatch(batchID)) { try harness.perform(.undoBatch(batchID)) }
  }

  @Test func aCopyTakenOutOfAnImportedCountIsntPartOfTheBatch() throws {
    var harness = Harness()
    let batch = ImportBatch(
      importer: "spreadsheet",
      fileName: "cables.csv",
      collectionName: "Câbles",
      rows: [ObjectDraft(type: "thing", values: [.title: .text("Câble péritel")], bulk: .quantity, quantity: 3)]
    )
    let events = try harness.perform(.importBatch(batch), as: .import)
    let id = try #require(events.compactMap { if case .added(let object, _) = $0.kind { object.id } else { nil } }.first)
    let promoted = try harness.perform(.promote(id))
    guard case .promoted(_, let copy) = promoted.first?.kind else { Issue.record("no copy"); return }
    #expect(copy.imported == nil)
    // Taking a copy out is the collector's work on the count.
    #expect(harness.shelf.objects[id]?.imported?.touched == true)
  }
}

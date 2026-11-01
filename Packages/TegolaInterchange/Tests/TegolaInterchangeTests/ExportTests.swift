import Foundation
import TegolaCatalogue
import TegolaModel
import Testing

@testable import TegolaInterchange

/// T8.2: export, and M8's exit test: export → import gives back the same shelf (D-81).
@Suite struct ExportTests {
  static let catalogue = try! Catalogue.bundled()
  static let now = Date(timeIntervalSince1970: 1_800_000_000)
  static let euro = Currency("EUR")!

  /// A shelf built through the model's own rules: `plan`, then `apply`.
  struct Builder {
    var shelf = Shelf()

    mutating func perform(_ command: ShelfCommand) throws {
      let context = PlanContext(at: ExportTests.now, catalogue: ExportTests.catalogue, makeID: { UUID() })
      shelf = apply(try plan(command, on: shelf, context: context), to: shelf)
    }

    @discardableResult
    mutating func add(_ type: TypeManifest.ID, subtype: String? = nil, _ values: [FieldKey: FieldValue]) throws
      -> ObjectID
    {
      let before = Set(shelf.objects.keys)
      let collection = shelf.collections.values.first { $0.typeID == type }.map { CollectionChoice.existing($0.id) }
      try perform(
        .add(
          ObjectDraft(type: type, subtype: subtype, values: values),
          to: collection ?? .new(name: type.rawValue),
          origin: .typed
        )
      )
      return try #require(Set(shelf.objects.keys).subtracting(before).first)
    }
  }

  /// Objects of every v1 type, with values each kind of template column carries.
  static func shelf() throws -> Builder {
    var builder = Builder()
    try builder.add(
      "video-game",
      subtype: "saturn",
      [
        .title: .text("Radiant Silvergun"), .year: .year(1998), .field("publisher"): .text("Treasure"),
        .field("region"): .text("NTSC-J"), .axis("boxCondition"): .text("Very good"),
        .axis("mediaCondition"): .text("Near mint"), .field("inserts"): .options(["manual", "disc"]),
        .notes: .text("From Kenji, \"mint\", 2019"),
      ]
    )
    try builder.add(
      "music",
      subtype: "vinyl",
      [
        .title: .text("Kid A"), .subtitle: .text("Radiohead"), .year: .year(2000), .condition: .text("Near Mint"),
        .field("label"): .text("Parlophone"), .field("catalogNumber"): .text("7243 5 27753 1 1"),
      ]
    )
    try builder.add(
      "board-games",
      [.title: .text("Brass: Birmingham"), .field("designer"): .text("Gavan Brown"), .field("playTime"): .number(120)]
    )
    try builder.add("thing", [.title: .text("Tin robot"), .notes: .text("Grandad's, line one\nline two")])
    return builder
  }

  /// The exit test: every object comes back with the same type, subtype and values.
  @Test func exportThenImportGivesBackTheSameShelf() async throws {
    let original = try Self.shelf().shelf
    let csv = ShelfExport.csv(original, catalogue: Self.catalogue)
    let input = ImportInput(fileName: "tegola.csv", data: Data(csv.utf8))
    #expect(TemplateImporter().recognises(input) == .certain)
    let plan = try await TemplateImporter().plan(input, catalogue: Self.catalogue, extraction: NoteReader())
    let exported = ShelfExport.exported(original)
    #expect(plan.rows.count == exported.count)
    // Each row added back through the model's rules, as Build my shelf would, is the object it came from.
    var back = Builder()
    for (object, row) in zip(exported, plan.rows) {
      let id = try back.add(row.draft.type, subtype: row.draft.subtype, row.draft.values)
      let returned = try #require(back.shelf.objects[id])
      #expect(returned.typeID == object.typeID)
      #expect(returned.subtype == object.subtype)
      #expect(returned.values == object.values, "\(object.title)")
    }
  }

  /// What the template can't carry goes into the note, never lost, and never money (promise 5).
  @Test func whatTheTemplateCantCarryGoesInTheNoteButNoMoney() throws {
    var builder = Builder()
    let acquired = Date(timeIntervalSince1970: 1_600_000_000)
    let id = try builder.add(
      "music",
      subtype: "vinyl",
      [
        .title: .text("Debut"), .acquired: .date(acquired),
        .paid: .money(Money(minorUnits: 4_000, currency: Self.euro)),
      ]
    )
    let object = try #require(builder.shelf.objects[id])
    let row = ShelfExport.row(object, catalogue: Self.catalogue)
    #expect(row["note"] == "acquired: 2020-09-13")
    #expect(!ShelfExport.csv(builder.shelf, catalogue: Self.catalogue).contains("40"))
  }

  /// Let go stays out of the CSV (it's in the archive and the JSON).
  @Test func letGoObjectsStayOutOfTheTemplate() throws {
    var builder = try Self.shelf()
    let robot = try #require(builder.shelf.objects.values.first { $0.title == "Tin robot" }?.id)
    try builder.perform(.letGo(robot, .gifted))
    #expect(!ShelfExport.csv(builder.shelf, catalogue: Self.catalogue).contains("Tin robot"))
  }

  /// The JSON keeps the whole shelf, and reads back the same.
  @Test func theJSONRoundTrips() throws {
    var builder = try Self.shelf()
    let kidA = try #require(builder.shelf.objects.values.first { $0.title == "Kid A" }?.id)
    try builder.perform(.lend(kidA, to: .new(name: "Max"), due: nil, note: ""))
    try builder.perform(.setPlace([kidA], PlacePath(typed: "Office › Shelf 2")))
    let data = try ShelfExport.json(builder.shelf, exportedAt: Self.now)
    let document = try ShelfExport.document(from: data)
    #expect(document.format == "tegola-shelf")
    #expect(document.version == 1)
    #expect(document.shelf == builder.shelf)
  }
}

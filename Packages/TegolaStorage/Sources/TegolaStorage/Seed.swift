#if DEBUG
  public import Foundation
  import TegolaCatalogue
  public import TegolaModel

  /// The shelf every preview, `--seed` launch and screen test starts from (PLAN §2.4). Debug builds only, so Release
  /// never contains it. Planted through `perform`, like any collector's shelf, so it's valid by construction and its
  /// history is real. It grows with the screens that need more (about 120 objects by M3).
  public enum Seed {
    /// The seed's objects, by type: a few of each v1 type, in the states the screens need to show.
    public static func plant(
      in store: ShelfStore,
      at start: Date,
      makeID: @escaping @Sendable () -> UUID
    ) throws {
      var planter = Planter(store: store, at: start, makeID: makeID)
      try planter.plant()
    }

    struct Planter {
      let store: ShelfStore
      var at: Date
      let makeID: @Sendable () -> UUID
      var collections: [String: CollectionID] = [:]

      init(store: ShelfStore, at: Date, makeID: @escaping @Sendable () -> UUID) {
        self.store = store
        // A week of history before the launch: every event a minute apart.
        self.at = at.addingTimeInterval(-7 * 24 * 3600)
        self.makeID = makeID
      }

      @discardableResult
      mutating func perform(_ command: ShelfCommand, as source: ShelfEvent.Source = .collector) throws
        -> CommandReceipt
      {
        let context = PlanContext(at: at, source: source, catalogue: store.catalogue, makeID: makeID)
        at += 60
        return try store.perform(command, context: context)
      }

      @discardableResult
      mutating func add(
        _ draft: ObjectDraft,
        in collection: String,
        origin: AddOrigin = .typed,
        as source: ShelfEvent.Source = .collector
      ) throws -> ObjectID {
        let choice = collections[collection].map(CollectionChoice.existing) ?? .new(name: collection)
        let receipt = try perform(.add(draft, to: choice, origin: origin), as: source)
        if let created = receipt.createdCollections.first { collections[collection] = created }
        return receipt.createdObjects[0]
      }

      static func game(_ title: String, _ subtype: String?, _ values: [FieldKey: FieldValue] = [:]) -> ObjectDraft {
        var values = values
        values[.title] = .text(title)
        return ObjectDraft(type: "video-game", subtype: subtype, values: values)
      }

      mutating func plant() throws {
        // Video games: a Saturn import with its ladder, a cart with a save battery, a grail, a wanted one, a capture.
        let silvergun = try add(
          Self.game(
            "Radiant Silvergun",
            "saturn",
            [
              .year: .year(1998), .field("publisher"): .text("Treasure"), .field("region"): .text("NTSC-J"),
              .axis("mediaCondition"): .text("Near mint"), .axis("boxCondition"): .text("Very good"),
              .axis("manualCondition"): .text("Good"), .field("spineCard"): .flag(true),
            ]
          ),
          in: "The Library"
        )
        try perform(.setGrail(silvergun, true))
        try perform(.setPlace([silvergun], PlacePath(typed: "Office › Shelf 2")))
        let pokemon = try add(
          Self.game(
            "Pokémon Red",
            "game-boy",
            [.year: .year(1998), .field("region"): .text("PAL"), .field("saveBattery"): .date(at)]
          ),
          in: "The Library"
        )
        try perform(.setPlace([pokemon], PlacePath(typed: "Office › Shelf 1")))
        try add(Self.game("Majora's Mask", "n64", [.field("expansionPak"): .text("Required")]), in: "The Library")
        try add(Self.game("Metal Slug", "neo-geo", [.field("board"): .text("AES")]), in: "The Library")
        var wanted = Self.game("Policenauts", "ps1")
        wanted.ownership = .wanted
        let policenauts = try add(wanted, in: "The Library")
        try perform(.setWanted(policenauts, priority: 1, priceCap: nil))
        try add(Self.game("Guardian Heroes", nil), in: "The Library", origin: .captured, as: .capture)

        // Music: one per format subtype, one lent.
        func release(_ title: String, _ artist: String, _ subtype: String) -> ObjectDraft {
          ObjectDraft(type: "music", subtype: subtype, values: [.title: .text(title), .subtitle: .text(artist)])
        }
        let kidA = try add(release("Kid A", "Radiohead", "vinyl"), in: "My Music")
        try perform(.lend(kidA, to: .new(name: "Max"), due: nil, note: "Back by the party"))
        try add(release("Homogenic", "Björk", "cd"), in: "My Music")
        try add(release("Nebraska", "Bruce Springsteen", "cassette"), in: "My Music")
        try add(release("Selected Ambient Works", "Aphex Twin", "other"), in: "My Music")

        // Board games: one borrowed, one let go.
        func boardGame(_ title: String, _ designer: String) -> ObjectDraft {
          ObjectDraft(type: "board-games", values: [.title: .text(title), .field("designer"): .text(designer)])
        }
        try add(boardGame("Brass: Birmingham", "Gavan Brown"), in: "Board games")
        let azul = try add(boardGame("Azul", "Michael Kiesling"), in: "Board games")
        try perform(.letGo(azul, .gifted))
        let root = try add(boardGame("Root", "Cole Wehrle"), in: "Board games")
        try perform(.markBorrowed(root, from: .new(name: "Léa")))

        // Things: a count, and one that needs details.
        try add(
          ObjectDraft(type: "thing", values: [.title: .text("Enamel pins")], bulk: .quantity, quantity: 12),
          in: "Things"
        )
        try add(ObjectDraft(type: "thing", values: [.title: .text("Tin robot")]), in: "Things")
        try add(ObjectDraft(type: "thing", needsDetails: true), in: "Things", origin: .captured, as: .capture)
      }
    }
  }
#endif

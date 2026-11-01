#if DEBUG
  public import Foundation
  import TegolaCatalogue
  public import TegolaModel

  /// The shelf every preview, `--seed` launch and screen test starts from (PLAN §2.4). Debug builds only, so Release
  /// never contains it. Planted through `perform`, like any collector's shelf, so it's valid by construction and its
  /// history is real. It grows with the screens that need more: about 120 objects from M4.
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
        var borrowed = boardGame("Root", "Cole Wehrle")
        borrowed.ownership = .borrowed
        let root = try add(borrowed, in: "Board games")
        try perform(.markBorrowed(root, from: .new(name: "Léa")))

        // Things: a count, and one that needs details.
        try add(
          ObjectDraft(type: "thing", values: [.title: .text("Enamel pins")], bulk: .quantity, quantity: 12),
          in: "Things"
        )
        try add(ObjectDraft(type: "thing", values: [.title: .text("Tin robot")]), in: "Things")
        try add(ObjectDraft(type: "thing", needsDetails: true), in: "Things", origin: .captured, as: .capture)

        try plantSignals()
        try plantCrowd()
      }

      /// The year of the seed's launch, in UTC: the clocks' ages count from it, so the seed reads the same any year.
      var launchYear: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.component(.year, from: at)
      }

      /// M4's states (F15, journey 5): exactly one object needs attention, a Game Boy cartridge whose save battery is
      /// due. Every other old cartridge has had its swap logged, one was dismissed, and a download code is good.
      mutating func plantSignals() throws {
        let year = launchYear
        func cart(_ title: String, _ subtype: String, age: Int) -> ObjectDraft {
          Self.game(title, subtype, [.year: .year(year - age), .field("region"): .text("PAL")])
        }
        try add(cart("Tetris", "game-boy", age: 30), in: "Carts & discs")
        let swapped: [(String, String, Int)] = [
          ("Super Mario Land 2", "game-boy", 34), ("Kirby's Dream Land", "game-boy", 34),
          ("Wario Land", "game-boy", 32), ("Donkey Kong Land", "game-boy", 31), ("Pokémon Blue", "game-boy", 28),
          ("Super Mario 64", "n64", 30), ("Mario Kart 64", "n64", 29), ("GoldenEye 007", "n64", 29),
          ("Banjo-Kazooie", "n64", 28), ("Ocarina of Time", "n64", 28), ("Paper Mario", "n64", 25),
        ]
        for (title, subtype, age) in swapped {
          let id = try add(cart(title, subtype, age: age), in: "Carts & discs")
          try perform(.logEvent(id, kind: ShelfEvent.Kind.servicedKind, note: ""))
        }
        // Dismissed: the collector knows this battery was replaced long ago and said so.
        let starFox = try add(cart("Star Fox 64", "n64", age: 29), in: "Carts & discs")
        if let object = try store.shelf().objects[starFox],
          let type = try? store.catalogue.resolve(object.typeID, subtype: object.subtype)
        {
          var calendar = Calendar(identifier: .gregorian)
          calendar.timeZone = TimeZone(identifier: "UTC")!
          for signal in signals(for: object, type: type, now: at, calendar: calendar) where signal.status.needsAttention
          {
            try perform(.dismissSignal(starFox, signal))
          }
        }
        // A download code, good for another year.
        try add(
          Self.game(
            "Hollow Knight",
            nil,
            [
              .year: .year(year - 8), .field("platform"): .text("Nintendo Switch"),
              .field("media"): .text("Download code"), .field("region"): .text("PAL"),
              .field("codeExpires"): .date(at.addingTimeInterval(365 * 24 * 3600)),
            ]
          ),
          in: "Carts & discs"
        )
        // Discs: disc rot is held back in v1 (PD-018), so these are fine.
        let discs: [(String, String, Int)] = [
          ("Panzer Dragoon Saga", "saturn", 28), ("Guardian Force", "saturn", 28), ("Nights into Dreams", "saturn", 30),
          ("Burning Rangers", "saturn", 28), ("Castlevania: Symphony of the Night", "ps1", 29),
          ("Final Fantasy VII", "ps1", 29), ("Vagrant Story", "ps1", 26), ("Silent Hill", "ps1", 27),
          ("Metal Gear Solid", "ps1", 28), ("Parasite Eve", "ps1", 28),
        ]
        for (title, subtype, age) in discs {
          try add(cart(title, subtype, age: age), in: "Carts & discs")
        }
      }

      /// The rest of the seed, toward 120 objects (M4): ordinary pieces with no clock, so the shelf feels lived in.
      mutating func plantCrowd() throws {
        let records: [(String, String, String)] = [
          ("Blue Train", "John Coltrane", "vinyl"), ("Kind of Blue", "Miles Davis", "vinyl"),
          ("A Love Supreme", "John Coltrane", "vinyl"), ("Moanin'", "Art Blakey", "vinyl"),
          ("Song for My Father", "Horace Silver", "vinyl"), ("Speak No Evil", "Wayne Shorter", "vinyl"),
          ("Maiden Voyage", "Herbie Hancock", "vinyl"), ("Unknown Pleasures", "Joy Division", "vinyl"),
          ("Disintegration", "The Cure", "vinyl"), ("Victorialand", "Cocteau Twins", "vinyl"),
          ("Loveless", "My Bloody Valentine", "vinyl"), ("Spirit of Eden", "Talk Talk", "vinyl"),
          ("Hounds of Love", "Kate Bush", "vinyl"), ("Remain in Light", "Talking Heads", "vinyl"),
          ("OK Computer", "Radiohead", "cd"), ("Mezzanine", "Massive Attack", "cd"), ("Dummy", "Portishead", "cd"),
          ("Debut", "Björk", "cd"), ("Endtroducing.....", "DJ Shadow", "cd"),
          ("Music Has the Right to Children", "Boards of Canada", "cd"),
          ("Laughing Stock", "Talk Talk", "cd"), ("Felt Mountain", "Goldfrapp", "cd"),
          ("In Rainbows", "Radiohead", "cd"), ("Vespertine", "Björk", "cd"),
          ("Doolittle", "Pixies", "cassette"), ("Daydream Nation", "Sonic Youth", "cassette"),
          ("Murmur", "R.E.M.", "cassette"), ("The Queen Is Dead", "The Smiths", "cassette"),
          ("Heaven or Las Vegas", "Cocteau Twins", "cassette"),
          ("Selected Ambient Works Volume II", "Aphex Twin", "other"),
        ]
        for (title, artist, subtype) in records {
          try add(
            ObjectDraft(type: "music", subtype: subtype, values: [.title: .text(title), .subtitle: .text(artist)]),
            in: "Record crates"
          )
        }
        let games: [(String, String)] = [
          ("Catan", "Klaus Teuber"), ("Carcassonne", "Klaus-Jürgen Wrede"), ("Ticket to Ride", "Alan R. Moon"),
          ("Pandemic", "Matt Leacock"), ("Codenames", "Vlaada Chvátil"), ("Wingspan", "Elizabeth Hargrave"),
          ("Terraforming Mars", "Jacob Fryxelius"), ("7 Wonders", "Antoine Bauza"), ("Dominion", "Donald X. Vaccarino"),
          ("Agricola", "Uwe Rosenberg"), ("Spirit Island", "R. Eric Reuss"), ("Gloomhaven", "Isaac Childres"),
          ("Hanabi", "Antoine Bauza"), ("The Crew", "Thomas Sing"), ("Patchwork", "Uwe Rosenberg"),
          ("Dixit", "Jean-Louis Roubira"), ("Splendor", "Marc André"), ("Concordia", "Mac Gerdts"),
          ("Puerto Rico", "Andreas Seyfarth"), ("Tigris & Euphrates", "Reiner Knizia"),
        ]
        for (title, designer) in games {
          try add(
            ObjectDraft(type: "board-games", values: [.title: .text(title), .field("designer"): .text(designer)]),
            in: "Game night"
          )
        }
        let things = [
          "Brass compass", "Tin wind-up duck", "Polaroid SX-70", "Swiss Army knife", "Enamel mug", "Snow globe",
          "Matchbox Mini Cooper", "Fountain pen", "Pocket watch", "Glass marbles", "Toy theatre", "Rubik's Cube",
          "Lomo LC-A", "Tamagotchi", "View-Master",
        ]
        for title in things {
          try add(ObjectDraft(type: "thing", values: [.title: .text(title)]), in: "Odds and ends")
        }
      }
    }
  }
#endif

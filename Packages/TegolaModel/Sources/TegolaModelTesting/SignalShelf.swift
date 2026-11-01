public import Foundation
public import TegolaCatalogue
public import TegolaModel

/// The M4 exit test's shelf (page 52, P2): 200 objects across the four v1 types, with clocks in every state, so the
/// owner can read the signal list it gives and say whether they agree with it on 8 of 10 (tasks/plan.md, T4.4). Built
/// through `plan` and `apply` like any shelf, from a fixed seed, so it's the same on every run.
public struct SignalShelf {
  /// The day the list is read on.
  public static let now: Date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!

  public static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  public private(set) var shelf = Shelf()
  public let catalogue: Catalogue
  private let ids = Counter()
  private var random: SplitMix
  private var collections: [String: CollectionID] = [:]

  public init(catalogue: Catalogue) throws {
    self.catalogue = catalogue
    random = SplitMix(seed: 2026_11_01)
    try plant()
  }

  // MARK: Planting

  private mutating func perform(_ command: ShelfCommand, at: Date, as source: ShelfEvent.Source = .collector) throws {
    let ids = ids
    let context = PlanContext(at: at, source: source, catalogue: catalogue, makeID: { ids.next() })
    shelf = apply(try plan(command, on: shelf, context: context), to: shelf)
  }

  private func day(_ year: Int, _ month: Int = 1) -> Date {
    Self.calendar.date(from: DateComponents(year: year, month: month, day: 1))!
  }

  /// Everything is added a week before `now`; care is logged on the day it happened.
  private var addedAt: Date { Self.now.addingTimeInterval(-7 * 24 * 3600) }

  @discardableResult
  private mutating func add(
    _ type: TypeManifest.ID,
    _ title: String,
    subtype: String?,
    year: Int?,
    values: [FieldKey: FieldValue] = [:],
    ownership: ShelfObject.Ownership = .owned,
    origin: AddOrigin = .typed
  ) throws -> ObjectID {
    var values = values
    values[.title] = .text(title)
    if let year { values[.year] = .year(year) }
    let draft = ObjectDraft(type: type, subtype: subtype, values: values, ownership: ownership)
    let name = "My \(type.rawValue)"
    let choice = collections[name].map(CollectionChoice.existing) ?? .new(name: name)
    let before = Set(shelf.objects.keys)
    let source: ShelfEvent.Source = origin == .captured ? .capture : .collector
    try perform(.add(draft, to: choice, origin: origin), at: addedAt, as: source)
    if collections[name] == nil { collections[name] = shelf.collections.values.first { $0.name == name }?.id }
    return Set(shelf.objects.keys).subtracting(before).first!
  }

  private mutating func plant() throws {
    try games()
    try music()
    try boardGames()
    try things()
  }

  /// 100 video games: cartridges with save batteries of every age, some replaced or swapped, and discs whose rot clock
  /// is held pending (D-56).
  private mutating func games() throws {
    let cartridges = [
      "Pokémon Red", "Pokémon Gold", "Link's Awakening", "Zelda: Oracle of Ages", "Wario Land II", "Tetris DX",
      "Super Mario 64", "Ocarina of Time", "Majora's Mask", "Paper Mario", "Banjo-Kazooie", "Pokémon Stadium",
      "Mario Kart 64", "GoldenEye 007", "F-Zero X", "Harvest Moon 64", "Kirby's Dream Land", "Metroid II",
    ]
    for index in 0..<60 {
      let title = "\(cartridges[index % cartridges.count]) (\(index + 1))"
      let subtype = index % 2 == 0 ? "game-boy" : "n64"
      let year = 1989 + random.next(below: 33)
      var values: [FieldKey: FieldValue] = [:]
      // One in six had its battery replaced, and the collector typed the date.
      if random.next(below: 6) == 0 { values[.field("saveBattery")] = .date(day(2005 + random.next(below: 18))) }
      let id = try add("video-game", title, subtype: subtype, year: year, values: values)
      // One in eight has a swap logged instead.
      if random.next(below: 8) == 0 {
        try perform(.logEvent(id, kind: CareKind.batterySwapped, note: ""), at: day(2015 + random.next(below: 11)))
      }
    }
    let discs = ["Panzer Dragoon Saga", "Radiant Silvergun", "Final Fantasy VII", "Metal Gear Solid", "Silent Hill"]
    for index in 0..<25 {
      let subtype = index % 2 == 0 ? "saturn" : "ps1"
      try add(
        "video-game",
        "\(discs[index % discs.count]) (\(index + 1))",
        subtype: subtype,
        year: 1994 + random.next(below: 7)
      )
    }
    for index in 0..<10 {
      try add(
        "video-game",
        "Metal Slug (\(index + 1))",
        subtype: "neo-geo",
        year: 1996,
        values: [.field("board"): .text("AES")]
      )
    }
    // Five wanted: the hunt never runs a clock.
    for index in 0..<5 {
      try add("video-game", "Earthbound (\(index + 1))", subtype: "n64", year: 1995, ownership: .wanted)
    }
  }

  /// 50 releases: CDs (disc rot, every five years), cassettes (media rot, every two), vinyl (no clock).
  private mutating func music() throws {
    let albums = ["Kind of Blue", "Blue Train", "Mezzanine", "OK Computer", "Homogenic", "Remain in Light"]
    let media = ["cd", "cassette", "vinyl"]
    for index in 0..<50 {
      let medium = media[index % media.count]
      let id = try add(
        "music",
        "\(albums[index % albums.count]) (\(index + 1))",
        subtype: medium,
        year: 1975 + random.next(below: 50)
      )
      // Some were checked recently: their clock has nothing to say yet.
      if random.next(below: 3) == 0 {
        try perform(.logEvent(id, kind: CareKind.checked, note: ""), at: day(2022 + random.next(below: 5)))
      }
    }
  }

  /// 30 board games: no clock, but they're lent the most, so loans fall due and run late.
  private mutating func boardGames() throws {
    let names = ["Catan", "Carcassonne", "Azul", "Root", "Wingspan", "Brass", "Twilight Struggle"]
    for index in 0..<30 {
      let id = try add(
        "board-games",
        "\(names[index % names.count]) (\(index + 1))",
        subtype: nil,
        year: 2000 + index % 24
      )
      switch index % 6 {
      case 0:
        // Lent, and due back last month: overdue.
        try perform(.lend(id, to: .new(name: "Dara"), due: day(2026, 10), note: ""), at: day(2026, 9))
      case 1:
        // Lent, due next month: just out.
        try perform(.lend(id, to: .new(name: "Max"), due: day(2026, 12), note: ""), at: day(2026, 10))
      default:
        break
      }
    }
  }

  /// 20 things: no clock; a few captured and unconfirmed, two let go, one borrowed.
  private mutating func things() throws {
    for index in 0..<20 {
      if index < 3 {
        try add("thing", "Found in the loft (\(index + 1))", subtype: nil, year: nil, origin: .captured)
      } else if index == 3 {
        try add("thing", "Dara's projector", subtype: nil, year: 2015, ownership: .borrowed)
      } else {
        let id = try add("thing", "Keepsake (\(index + 1))", subtype: nil, year: 1950 + index)
        if index >= 18 { try perform(.letGo(id, .gifted), at: addedAt) }
      }
    }
  }

  // MARK: Dismissals

  /// Dismisses the first `count` objects with a watch-level save-battery signal, as a collector who had seen them
  /// would: those stay hidden, and one that has since reached act shows again.
  public mutating func dismissWatchedBatteries(count: Int) throws {
    let readings = StatusReading.all(shelf: shelf, catalogue: catalogue, now: Self.now, calendar: Self.calendar)
    let watched = shelf.objects.values
      .filter {
        if case .clock(let signal) = readings[$0.id]?.reason {
          signal.clock == "saveBattery" && signal.status == .watch
        } else {
          false
        }
      }
      .sorted { $0.title < $1.title }
      .prefix(count)
    for object in watched {
      try perform(.dismissSignal(object.id, clock: "saveBattery", status: .watch), at: addedAt)
    }
  }
}

/// SplitMix64: a small, fixed pseudo-random generator, so the shelf is the same everywhere.
struct SplitMix {
  private var state: UInt64

  init(seed: UInt64) { state = seed }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  mutating func next(below bound: Int) -> Int { Int(next() % UInt64(bound)) }
}

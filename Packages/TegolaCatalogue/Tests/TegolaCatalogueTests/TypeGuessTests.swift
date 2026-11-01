import Testing

@testable import TegolaCatalogue

/// The first piece's type is inferred, not asked (PD-166): page 46's examples, and the cases it must not get wrong.
@Suite struct TypeGuessTests {
  let catalogue: Catalogue

  init() throws { catalogue = try Catalogue.bundled() }

  @Test func ocarinaOfTimeIsAnN64Game() {
    let guess = catalogue.guess(from: "Ocarina of Time, Nintendo 64 cartridge, PAL, 1998")
    #expect(guess == TypeGuess(type: "video-game", subtype: "n64", isEnabled: true))
  }

  /// 46, 2B: watches ship as data only, so the piece will be saved as a Thing that waits for them.
  @Test func anOmegaIsAWatchThatHasntShipped() {
    let guess = catalogue.guess(from: "Omega Seamaster, 1968")
    #expect(guess == TypeGuess(type: "watches", subtype: nil, isEnabled: false))
  }

  @Test func chateauMusarIsWineWithAccentsIgnored() {
    #expect(catalogue.guess(from: "Château Musar 2015, red wine")?.type == "wine")
  }

  @Test(
    arguments: [
      ("Kind of Blue, vinyl LP", "music", "vinyl"),
      ("Mezzanine on CD", "music", "cd"),
      ("A Catan board game", "board-games", nil),
      ("Panzer Dragoon Saga, Sega Saturn", "video-game", "saturn"),
      ("Blade Runner on Blu-ray", "video-media", "blu-ray"),
    ] as [(String, TypeManifest.ID, String?)]
  )
  func theLaunchTypesAndTheirSubtypes(_ text: String, _ type: TypeManifest.ID, _ subtype: String?) {
    let guess = catalogue.guess(from: text)
    #expect(guess?.type == type)
    #expect(guess?.subtype == subtype)
  }

  /// Words match whole: a cartridge isn't a car, and a card isn't a car either.
  @Test func wordsMatchWhole() {
    #expect(catalogue.guess(from: "Game Boy cartridge")?.type == "video-game")
    #expect(catalogue.guess(from: "a postcard") == nil)
  }

  @Test func nothingRecognisedIsNoGuess() {
    #expect(catalogue.guess(from: "") == nil)
    #expect(catalogue.guess(from: "a blue thing from the loft") == nil)
  }

  /// Two types named equally is no guess: the collector says what it is, rather than the app picking one.
  @Test func aTieIsNoGuess() {
    #expect(catalogue.guess(from: "a watch and a bottle of wine") == nil)
  }

  /// A word in two type files would make one of them unguessable whenever it's said.
  @Test func noWordNamesTwoTypes() {
    var owners: [String: Set<TypeManifest.ID>] = [:]
    for manifest in catalogue.manifests {
      let words = manifest.recognise + manifest.subtypes.flatMap(\.recognise)
      for word in words { owners[Catalogue.words(word).joined(separator: " "), default: []].insert(manifest.id) }
    }
    let shared = owners.filter { $0.value.count > 1 }
    #expect(shared.isEmpty, "\(shared)")
  }

  /// Every type but Thing can be guessed, and so can every subtype of the four v1 types but music's Other.
  @Test func everyTypeAndLaunchSubtypeHasWords() {
    for manifest in catalogue.manifests where manifest.id != "thing" {
      #expect(!manifest.recognise.isEmpty, "\(manifest.id.rawValue)")
    }
    #expect(catalogue.manifest("thing")?.recognise.isEmpty == true)
    for manifest in catalogue.enabled {
      for subtype in manifest.subtypes where subtype.key != "other" {
        #expect(!subtype.recognise.isEmpty, "\(manifest.id.rawValue)/\(subtype.key)")
      }
    }
  }
}

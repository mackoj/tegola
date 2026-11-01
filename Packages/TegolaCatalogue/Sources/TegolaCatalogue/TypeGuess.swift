import Foundation

/// The type a description of a piece names: what the first piece's "That's it / Not quite" shows (PLAN F2, PD-166).
/// The on-device model, or the text a capture reads, describes the piece in words; the type files' `recognise` words
/// turn that into a type (D-62).
public struct TypeGuess: Hashable, Sendable {
  public let type: TypeManifest.ID
  /// Nil when no subtype's words were named, or two were named equally.
  public let subtype: String?
  /// False for a type that ships as data only (D-23): the piece is saved as a Thing that waits for it (46, 2B).
  public let isEnabled: Bool

  public init(type: TypeManifest.ID, subtype: String?, isEnabled: Bool) {
    self.type = type
    self.subtype = subtype
    self.isEnabled = isEnabled
  }
}

extension Catalogue {
  /// The one type the text names most, or nil when it names none, or two equally. Thing is never guessed: it's what
  /// a collector gets when nothing is.
  ///
  /// A type scores one point for each of its words the text contains, plus the points of its best subtype. Words are
  /// matched whole and in order, without case or accents: "Seamaster" names watches, "cartridge" doesn't name cars.
  public func guess(from text: String) -> TypeGuess? {
    let words = Self.words(text)
    guard !words.isEmpty else { return nil }
    let scored = manifests.compactMap { manifest -> (guess: TypeGuess, score: Int)? in
      let own = manifest.recognise.count { Self.contains(words, phrase: $0) }
      let subtypes = manifest.subtypes
        .map { subtype in (key: subtype.key, score: subtype.recognise.count { Self.contains(words, phrase: $0) }) }
        .filter { $0.score > 0 }
      let best = subtypes.map(\.score).max() ?? 0
      let leaders = subtypes.filter { $0.score == best }
      let score = own + best
      guard score > 0 else { return nil }
      let guess = TypeGuess(
        type: manifest.id,
        subtype: leaders.count == 1 ? leaders[0].key : nil,
        isEnabled: Self.enabledInV1.contains(manifest.id)
      )
      return (guess, score)
    }
    guard let top = scored.map(\.score).max() else { return nil }
    let leaders = scored.filter { $0.score == top }
    return leaders.count == 1 ? leaders[0].guess : nil
  }

  /// Lowercase words without accents, split on anything that isn't a letter or a digit ("Blu-ray" → blu, ray).
  static func words(_ text: String) -> [Substring] {
    text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
      .lowercased()
      .split { !$0.isLetter && !$0.isNumber }
  }

  static func contains(_ words: [Substring], phrase: String) -> Bool {
    let phrase = Self.words(phrase)
    guard !phrase.isEmpty, phrase.count <= words.count else { return false }
    return (0...(words.count - phrase.count)).contains { start in
      words[start..<(start + phrase.count)].elementsEqual(phrase)
    }
  }
}

public import Dependencies
import DependenciesMacros
public import Foundation

/// What the on-device model says a piece is: its name, and the plain words that say what kind of thing it is. The
/// model never picks a type: `Catalogue.guess(from:)` reads `words` against the type files (D-62, D-72).
public struct PieceDescription: Hashable, Sendable {
  /// The name as printed or commonly known ("Omega Seamaster"). Nil when nothing named it.
  public var name: String?
  /// What kind of object it is, in a few words ("wristwatch", "watch").
  public var words: [String]
  /// The year it was made or released, when it's printed on it or well known: what a clock reads first (46's payoff).
  public var year: Int?

  public init(name: String? = nil, words: [String] = [], year: Int? = nil) {
    self.name = name
    self.words = words
    self.year = year
  }

  /// The text the type guess reads: the words, then the name (a name like "Game Boy Camera" names its type too).
  public var guessText: String { (words + [name].compactMap(\.self)).joined(separator: " ") }
}

/// Describes a piece from a photo or a typed line (PLAN F2, T5.5). The live value is Apple's on-device model, with the
/// photo itself where the model can read images (iOS 27), else with the text and labels Vision reads from it. Without
/// Apple Intelligence, a photo still gets Vision's labels as words, and typed text is read as it is (D-72).
@DependencyClient
public struct ExtractionClient: Sendable {
  /// Whether the on-device model can run here. False means a photo gets only Vision's words, with no name.
  public var isModelAvailable: @Sendable () -> Bool = { false }
  /// A photo, as image data (JPEG or HEIC).
  public var describePhoto: @Sendable (_ data: Data) async throws -> PieceDescription
  /// A line the collector typed ("my grandfather's Omega").
  public var describeText: @Sendable (_ text: String) async throws -> PieceDescription
}

extension ExtractionClient: TestDependencyKey {
  /// Unimplemented: a test says what the model answered.
  public static let testValue = ExtractionClient()

  /// Previews describe every photo as a 1968 Omega Seamaster, and read typed text as it is.
  public static let previewValue = ExtractionClient(
    isModelAvailable: { true },
    describePhoto: { _ in PieceDescription(name: "Omega Seamaster", words: ["wristwatch"], year: 1968) },
    describeText: { text in PieceDescription(name: text, words: []) }
  )

  /// No on-device model: what a device without Apple Intelligence does with typed text.
  public static let unavailable = ExtractionClient(
    isModelAvailable: { false },
    describePhoto: { _ in PieceDescription() },
    describeText: { text in PieceDescription(name: text, words: []) }
  )
}

extension DependencyValues {
  public var extraction: ExtractionClient {
    get { self[ExtractionClient.self] }
    set { self[ExtractionClient.self] = newValue }
  }
}

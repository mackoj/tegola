#if canImport(FoundationModels) && canImport(Vision)
  import CoreGraphics
  public import Dependencies
  import Foundation
  import FoundationModels
  import ImageIO
  import Vision

  extension ExtractionClient: DependencyKey {
    public static var liveValue: ExtractionClient {
      ExtractionClient(
        isModelAvailable: { SystemLanguageModel.default.isAvailable },
        describePhoto: { data in try await LiveExtraction.describe(photo: data) },
        describeText: { text in try await LiveExtraction.describe(text: text) }
      )
    }
  }

  /// The model's answer, in the shape guided generation fills.
  @Generable
  struct GeneratedDescription {
    @Guide(
      description: "The object's name as printed on it or as collectors know it, without its type. Empty if unknown."
    )
    var name: String
    @Guide(
      description: "Up to six plain English words or short phrases for what kind of object it is, most specific first.",
      .maximumCount(6)
    )
    var words: [String]
    @Guide(description: "The year it was made or released, if printed on it or well known. 0 if unknown.")
    var year: Int
  }

  enum LiveExtraction {
    static let instructions = """
      You identify one physical object a collector owns, from a photo or their words. Say what it's called and what \
      kind of object it is (for example: wristwatch; vinyl record; board game; Game Boy cartridge; wine bottle). \
      Never guess a price or anything about its owner.
      """

    static func describe(text: String) async throws -> PieceDescription {
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard SystemLanguageModel.default.isAvailable, !trimmed.isEmpty else {
        return PieceDescription(name: trimmed.isEmpty ? nil : trimmed)
      }
      let session = LanguageModelSession(instructions: instructions)
      let answer = try await session.respond(
        to: "The collector describes it as: \(trimmed)",
        generating: GeneratedDescription.self
      ).content
      // The collector's own words name it; the model only adds what kind of thing it is.
      return PieceDescription(name: trimmed, words: answer.words, year: Self.year(answer.year))
    }

    static func describe(photo data: Data) async throws -> PieceDescription {
      let seen = try await VisionReading(photo: data)
      guard SystemLanguageModel.default.isAvailable else {
        return PieceDescription(name: nil, words: seen.labels)
      }
      let session = LanguageModelSession(instructions: instructions)
      let answer: GeneratedDescription
      if #available(iOS 27, macOS 27, *), SystemLanguageModel.default.capabilities.contains(.vision),
        let image = seen.image
      {
        answer = try await session.respond(generating: GeneratedDescription.self) {
          "Describe the object in this photo. Text read from it: \(seen.text)"
          Attachment(image)
        }.content
      } else {
        answer = try await session.respond(
          to: """
            A photo of the object. Text read from it: \(seen.text)
            What the photo shows, by an image classifier: \(seen.labels.joined(separator: ", "))
            """,
          generating: GeneratedDescription.self
        ).content
      }
      let name = answer.name.trimmingCharacters(in: .whitespacesAndNewlines)
      return PieceDescription(
        name: name.isEmpty ? nil : name,
        words: answer.words + seen.labels,
        year: Self.year(answer.year)
      )
    }

    /// A year worth keeping: the model says 0 when it doesn't know, and a clock can't read the future.
    static func year(_ year: Int) -> Int? {
      @Dependency(\.date.now) var now
      @Dependency(\.calendar) var calendar
      return (1800...calendar.component(.year, from: now)).contains(year) ? year : nil
    }
  }

  /// What Vision reads from a photo without the language model: its text, and the classifier's confident labels.
  struct VisionReading {
    var text: String
    var labels: [String]
    var image: CGImage?

    init(photo data: Data) async throws {
      let source = CGImageSourceCreateWithData(data as CFData, nil)
      image = source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
      let lines = try await RecognizeTextRequest().perform(on: data)
      text = lines.compactMap { $0.topCandidates(1).first?.string }.prefix(20).joined(separator: "\n")
      let classes = try await ClassifyImageRequest().perform(on: data)
      // The taxonomy's ids read as words ("wristwatch", "vinyl_record"); only the confident ones are worth guessing on.
      labels = classes.filter { $0.confidence > 0.3 }.sorted { $0.confidence > $1.confidence }.prefix(6).map {
        $0.identifier.replacing("_", with: " ")
      }
    }
  }
#endif

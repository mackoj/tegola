public import Dependencies
import DependenciesMacros
public import Foundation
public import TegolaCatalogue
public import TegolaModel

/// What the app knows about one object, for a lookup: the contract's `IdentifyHints`, in the model's words. Every part
/// is optional; a lookup needs at least one (D-71).
public struct LookupHints: Hashable, Sendable {
  public var title: String?
  public var subtitle: String?
  /// OCR text, newline-separated.
  public var text: String?
  public var catalogueNumber: String?
  public var barcode: String?
  public var year: Int?
  public var subtype: String?
  public var region: String?

  public init(
    title: String? = nil,
    subtitle: String? = nil,
    text: String? = nil,
    catalogueNumber: String? = nil,
    barcode: String? = nil,
    year: Int? = nil,
    subtype: String? = nil,
    region: String? = nil
  ) {
    self.title = title
    self.subtitle = subtitle
    self.text = text
    self.catalogueNumber = catalogueNumber
    self.barcode = barcode
    self.year = year
    self.subtype = subtype
    self.region = region
  }
}

/// One import row sent for matching (49, step 4), with the app's handle for it.
public struct MatchRow: Hashable, Sendable {
  public var ref: String
  public var title: String
  public var subtitle: String?
  public var year: Int?
  public var subtype: String?
  public var region: String?
  /// The words around the title that might name a variant. Never the collector's notes about condition or story.
  public var note: String?

  public init(
    ref: String,
    title: String,
    subtitle: String? = nil,
    year: Int? = nil,
    subtype: String? = nil,
    region: String? = nil,
    note: String? = nil
  ) {
    self.ref = ref
    self.title = title
    self.subtitle = subtitle
    self.year = year
    self.subtype = subtype
    self.region = region
    self.note = note
  }
}

/// Why a lookup didn't answer. The queue reads it: wait, spend an attempt, or give up (D-69, D-73).
public enum LookupFailure: Error, Hashable, Sendable {
  /// `429` or `503`: try again after this many seconds, no attempt spent.
  case retryAfter(TimeInterval)
  /// The network or the server failed: one attempt spent.
  case unavailable
  /// The server refused the request as sent (`400`, `401`, `403`, `413`, `415`): retrying won't help.
  case rejected(status: Int)
}

/// Lookups through tegola-server (PLAN §7). Features see model candidates, never the generated types. The live value
/// signs every call with App Attest, or a debug token in debug builds on a simulator.
@DependencyClient
public struct LookupClient: Sendable {
  /// `GET /types/{type}/barcodes/{code}`.
  public var barcode:
    @Sendable (_ type: TypeManifest.ID, _ code: String, _ subtype: String?) async throws -> [LookupCandidate]
  /// `POST /types/{type}/identify`: the hints as JSON, or with a JPEG as multipart (D-71).
  public var identify:
    @Sendable (_ type: TypeManifest.ID, _ hints: LookupHints, _ photo: Data?) async throws -> [LookupCandidate]
  /// `POST /types/{type}/match`, at most 50 rows: each row's outcome, by its ref.
  public var match: @Sendable (_ type: TypeManifest.ID, _ rows: [MatchRow]) async throws -> [String: MatchOutcome]
}

extension LookupClient: TestDependencyKey {
  /// Unimplemented: a test says what the server answered.
  public static let testValue = LookupClient()
  /// Previews answer nothing, as a server that knows nothing would.
  public static let previewValue = LookupClient(
    barcode: { _, _, _ in [] },
    identify: { _, _, _ in [] },
    match: { _, rows in Dictionary(uniqueKeysWithValues: rows.map { ($0.ref, .unknown) }) }
  )
}

extension DependencyValues {
  public var lookup: LookupClient {
    get { self[LookupClient.self] }
    set { self[LookupClient.self] = newValue }
  }
}

extension LookupClient {
  /// The call a queued request makes: a barcode is a barcode lookup; a catalogue number or text is identify (D-73).
  public func answer(_ request: LookupQueue.Request) async throws -> [LookupCandidate] {
    switch request.identifier {
    case .barcode(let code):
      try await barcode(request.type, code, request.subtype)
    case .catalogueNumber(let number):
      try await identify(request.type, LookupHints(catalogueNumber: number, subtype: request.subtype), nil)
    case .text(let text):
      try await identify(request.type, LookupHints(text: text, subtype: request.subtype), nil)
    }
  }
}

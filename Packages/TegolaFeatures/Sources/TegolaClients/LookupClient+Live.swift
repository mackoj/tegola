public import Dependencies
public import Foundation
import HTTPTypes
public import OpenAPIRuntime
import OpenAPIURLSession
import TegolaCatalogue
import TegolaLookupAPI
import TegolaModel

/// Where tegola-server is, and the debug token a simulator sends instead of App Attest (contract, security step 3).
/// Release builds use the production host. Debug builds read `TEGOLA_LOOKUP_URL` and `TEGOLA_DEBUG_TOKEN` from the
/// scheme's environment, so no token is ever in the app bundle (D-73).
public struct LookupConfiguration: Sendable {
  public var serverURL: URL
  public var debugToken: String?

  public init(serverURL: URL, debugToken: String? = nil) {
    self.serverURL = serverURL
    self.debugToken = debugToken
  }

  public static var main: LookupConfiguration {
    #if DEBUG
      let environment = ProcessInfo.processInfo.environment
      let url = environment["TEGOLA_LOOKUP_URL"].flatMap(URL.init(string:))
      let token = environment["TEGOLA_DEBUG_TOKEN"].flatMap { $0.isEmpty ? nil : $0 }
    #else
      let url: URL? = nil
      let token: String? = nil
    #endif
    return LookupConfiguration(serverURL: url ?? URL(string: "https://api.tegola.app/v1")!, debugToken: token)
  }
}

extension LookupClient: DependencyKey {
  public static var liveValue: LookupClient { .live(.main) }

  /// The generated client over an ephemeral `URLSession` (no cookies, no cache on disk), signed by
  /// `AppAttestMiddleware`. Registration uses a client without it: those two calls are public.
  public static func live(_ configuration: LookupConfiguration, transport: (any ClientTransport)? = nil) -> LookupClient {
    @Dependency(\.catalogue) var catalogue
    let transport = transport ?? URLSessionTransport(configuration: .init(session: URLSession(configuration: .ephemeral)))
    let plain = Client(serverURL: configuration.serverURL, transport: transport)
    let signer = AppAttestMiddleware(debugToken: configuration.debugToken) {
      try await AppAttestMiddleware.register(with: plain)
    }
    let client = Client(serverURL: configuration.serverURL, transport: transport, middlewares: [signer])
    let mapping = LookupMapping(catalogue: catalogue)
    return LookupClient(
      barcode: { type, code, subtype in
        let output = try await client.lookupBarcode(
          path: .init(typeID: type.rawValue, code: code),
          query: .init(subtype: subtype)
        )
        switch output {
        case .ok(let ok): return try mapping.candidates(ok.body.json.candidates)
        case .tooManyRequests(let wait): throw LookupFailure.retryAfter(TimeInterval(wait.headers.retryAfter ?? 60))
        case .serviceUnavailable(let wait): throw LookupFailure.retryAfter(TimeInterval(wait.headers.retryAfter ?? 60))
        case .badRequest: throw LookupFailure.rejected(status: 400)
        case .unauthorized: throw LookupFailure.rejected(status: 401)
        case .forbidden: throw LookupFailure.rejected(status: 403)
        case .undocumented(let status, _): throw status >= 500 ? LookupFailure.unavailable : .rejected(status: status)
        }
      },
      identify: { type, hints, photo in
        let json = mapping.hints(hints)
        let body: Operations.IdentifyObject.Input.Body
        if let photo {
          body = .multipartForm([
            .image(.init(payload: .init(body: HTTPBody(photo)))),
            .hints(.init(payload: .init(body: json))),
          ])
        } else {
          body = .json(json)
        }
        let output = try await client.identifyObject(path: .init(typeID: type.rawValue), body: body)
        switch output {
        case .ok(let ok): return try mapping.candidates(ok.body.json.candidates)
        case .tooManyRequests(let wait): throw LookupFailure.retryAfter(TimeInterval(wait.headers.retryAfter ?? 60))
        case .serviceUnavailable(let wait): throw LookupFailure.retryAfter(TimeInterval(wait.headers.retryAfter ?? 60))
        case .badRequest: throw LookupFailure.rejected(status: 400)
        case .unauthorized: throw LookupFailure.rejected(status: 401)
        case .forbidden: throw LookupFailure.rejected(status: 403)
        case .contentTooLarge: throw LookupFailure.rejected(status: 413)
        case .unsupportedMediaType: throw LookupFailure.rejected(status: 415)
        case .undocumented(let status, _): throw status >= 500 ? LookupFailure.unavailable : .rejected(status: status)
        }
      },
      match: { type, rows in
        let output = try await client.matchBatch(
          path: .init(typeID: type.rawValue),
          body: .json(.init(items: rows.map(mapping.item)))
        )
        switch output {
        case .ok(let ok): return try mapping.outcomes(ok.body.json.results)
        case .tooManyRequests(let wait): throw LookupFailure.retryAfter(TimeInterval(wait.headers.retryAfter ?? 60))
        case .serviceUnavailable(let wait): throw LookupFailure.retryAfter(TimeInterval(wait.headers.retryAfter ?? 60))
        case .badRequest: throw LookupFailure.rejected(status: 400)
        case .unauthorized: throw LookupFailure.rejected(status: 401)
        case .forbidden: throw LookupFailure.rejected(status: 403)
        case .contentTooLarge: throw LookupFailure.rejected(status: 413)
        case .undocumented(let status, _): throw status >= 500 ? LookupFailure.unavailable : .rejected(status: status)
        }
      }
    )
  }
}

/// The contract's types in the model's terms (D-69): values keyed and shaped as the object would hold them, by the
/// type's own fields. A key the type doesn't declare, or a value of the wrong shape, is left out.
struct LookupMapping: Sendable {
  let catalogue: Catalogue

  func candidates(_ candidates: [Components.Schemas.Candidate]) -> [LookupCandidate] {
    candidates.compactMap(candidate)
  }

  func candidate(_ candidate: Components.Schemas.Candidate) -> LookupCandidate? {
    let type = TypeManifest.ID(rawValue: candidate.typeID)
    guard let resolved = try? catalogue.resolve(type, subtype: candidate.subtype) else { return nil }
    var values: [FieldKey: FieldValue] = [.title: .text(candidate.title)]
    if let subtitle = candidate.subtitle { values[.subtitle] = .text(subtitle) }
    if let year = candidate.year { values[.year] = .year(year) }
    for (key, value) in candidate.fields?.additionalProperties ?? [:] {
      guard let field = resolved.field(key), let mapped = Self.value(value, as: field.field.kind) else { continue }
      values[.field(key)] = mapped
    }
    return LookupCandidate(
      releaseID: candidate.releaseID,
      type: type,
      subtype: candidate.subtype,
      values: values,
      confidence: candidate.confidence,
      reasons: candidate.reasons.compactMap { LookupCandidate.Reason(rawValue: $0.kind.rawValue) },
      sources: candidate.sources.map { LookupCandidate.Source(name: $0.name, attribution: $0.attribution) }
    )
  }

  /// A contract value in a field's kind. Kinds a lookup never fills (scales, logs, photos, money) give nothing.
  static func value(_ value: Components.Schemas.FieldValue, as kind: FieldKind) -> FieldValue? {
    switch (kind, value) {
    case (.text, .case1(let text)), (.choice, .case1(let text)): .text(text)
    case (.number, .case2(let number)): .number(number)
    case (.yesNo, .case3(let flag)): .flag(flag)
    case (.year, .case2(let number)): .year(Int(number))
    case (.date, .case1(let text)): Self.day(text).map(FieldValue.date)
    case (.yearRange, .case4(let range)): .yearRange(from: range.from, to: range.to)
    default: nil
    }
  }

  /// A full-date ("2027-03-01") at the start of its day, UTC.
  static func day(_ text: String) -> Date? {
    var format = Date.ISO8601FormatStyle().year().month().day()
    format.timeZone = .gmt
    return try? format.parse(text)
  }

  func hints(_ hints: LookupHints) -> Components.Schemas.IdentifyHints {
    Components.Schemas.IdentifyHints(
      title: hints.title,
      subtitle: hints.subtitle,
      text: hints.text,
      catalogueNumber: hints.catalogueNumber,
      barcode: hints.barcode.map { .init(code: $0) },
      year: hints.year,
      subtype: hints.subtype,
      region: hints.region
    )
  }

  func item(_ row: MatchRow) -> Components.Schemas.MatchItem {
    Components.Schemas.MatchItem(
      ref: row.ref,
      title: row.title,
      subtitle: row.subtitle,
      year: row.year,
      subtype: row.subtype,
      region: row.region,
      note: row.note
    )
  }

  func outcomes(_ results: [Components.Schemas.MatchResult.ResultsPayloadPayload]) -> [String: MatchOutcome] {
    Dictionary(
      results.map { result -> (String, MatchOutcome) in
        let found = candidates(result.candidates)
        let outcome: MatchOutcome =
          switch result.bucket {
          case .matched: found.first.map(MatchOutcome.matched) ?? .unknown
          case .ambiguous: found.isEmpty ? .unknown : .ambiguous(found)
          case .unknown: .unknown
          }
        return (result.ref, outcome)
      },
      uniquingKeysWith: { first, _ in first }
    )
  }
}

import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing

@testable import TegolaLookupAPI

/// Recorded server responses go through the generated client, so a change to the contract that the app can't read
/// fails here before it fails on a phone (PLAN §7).
@Suite struct ContractTests {
  @Test func barcodeLookupDecodesCandidatesWithTheirReasonsAndSources() async throws {
    let transport = RecordedTransport(status: .ok, file: "lookupBarcode-200")
    let client = Client(serverURL: URL(string: "https://api.test/v1")!, transport: transport)

    let response = try await client.lookupBarcode(
      path: .init(typeID: "video-game", code: "0711719200020"),
      query: .init(symbology: .ean13, subtype: "ps1", region: "PAL")
    )
    let candidates = try response.ok.body.json.candidates
    let ridgeRacer = try #require(candidates.first)
    #expect(ridgeRacer.title == "Ridge Racer")
    #expect(ridgeRacer.confidence == 0.97)
    #expect(ridgeRacer.reasons.map(\.kind) == [.barcode])
    #expect(ridgeRacer.sources.first?.attribution == "Data from IGDB")
    #expect(ridgeRacer.fields?.additionalProperties["publisher"] == .case1("Namco"))

    let request = try #require(transport.requests.first)
    #expect(request.method == .get)
    #expect(request.path == "/v1/types/video-game/barcodes/0711719200020?symbology=ean13&subtype=ps1&region=PAL")
  }

  @Test func matchBatchKeepsRequestOrderAndBuckets() async throws {
    let transport = RecordedTransport(status: .ok, file: "matchBatch-200")
    let client = Client(serverURL: URL(string: "https://api.test/v1")!, transport: transport)

    let response = try await client.matchBatch(
      path: .init(typeID: "video-game"),
      body: .json(
        .init(items: [
          .init(ref: "r1", title: "Donckey Kong Country 2", subtype: "snes", region: "PAL"),
          .init(ref: "r2", title: "Chine", subtype: "pc"),
        ])
      )
    )
    let results = try response.ok.body.json.results
    #expect(results.map(\.ref) == ["r1", "r2"])
    #expect(results.map(\.bucket) == [.matched, .unknown])
    #expect(results[0].candidates.first?.reasons.map(\.kind) == [.typoCorrected, .subtype])
  }

  /// Words alone go as JSON (D-71).
  @Test func identifyWithWordsSendsJSON() async throws {
    let transport = RecordedTransport(status: .ok, file: "identifyObject-200")
    let client = Client(serverURL: URL(string: "https://api.test/v1")!, transport: transport)

    let response = try await client.identifyObject(
      path: .init(typeID: "video-game"),
      body: .json(.init(title: "Ridge Racer", subtype: "ps1", region: "PAL"))
    )
    #expect(try response.ok.body.json.candidates.first?.title == "Ridge Racer")
    let request = try #require(transport.requests.first)
    #expect(request.method == .post)
    #expect(request.path == "/v1/types/video-game/identify")
    #expect(request.headerFields[.contentType]?.hasPrefix("application/json") == true)
  }

  /// A photo goes as multipart, with the hints beside it, and a candidate it supports says so (D-71).
  @Test func identifyWithAPhotoSendsMultipartAndReadsTheImageReason() async throws {
    let transport = RecordedTransport(status: .ok, file: "identifyObject-200")
    let client = Client(serverURL: URL(string: "https://api.test/v1")!, transport: transport)
    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])

    let response = try await client.identifyObject(
      path: .init(typeID: "video-game"),
      body: .multipartForm([
        .image(.init(payload: .init(body: HTTPBody(jpeg)))),
        .hints(
          .init(
            payload: .init(
              body: .init(text: "RIDGE RACER\nSCES-00001", barcode: .init(code: "0711719200020", symbology: .ean13))
            )
          )
        ),
      ])
    )
    let candidate = try #require(try response.ok.body.json.candidates.first)
    #expect(candidate.reasons.map(\.kind) == [.image, .ocr])
    let request = try #require(transport.requests.first)
    #expect(request.headerFields[.contentType]?.hasPrefix("multipart/form-data; boundary=") == true)
  }

  @Test func tooManyRequestsCarriesRetryAfter() async throws {
    let transport = RecordedTransport(
      status: .tooManyRequests,
      file: "problem-429",
      contentType: "application/problem+json",
      extraHeaders: [.retryAfter: "30"]
    )
    let client = Client(serverURL: URL(string: "https://api.test/v1")!, transport: transport)

    let response = try await client.identifyObject(
      path: .init(typeID: "board-games"),
      body: .json(.init(title: "Catan"))
    )
    guard case let .tooManyRequests(tooMany) = response else {
      Issue.record("expected 429, got \(response)")
      return
    }
    #expect(tooMany.headers.retryAfter == 30)
    #expect(try tooMany.body.applicationProblemJson.status == 429)
  }
}

/// A transport that answers every request with a recorded file and remembers what was asked.
final class RecordedTransport: ClientTransport, @unchecked Sendable {
  let status: HTTPResponse.Status
  let file: String
  let contentType: String
  let extraHeaders: HTTPFields
  private let lock = NSLock()
  private var recorded: [HTTPRequest] = []

  init(
    status: HTTPResponse.Status,
    file: String,
    contentType: String = "application/json",
    extraHeaders: HTTPFields = [:]
  ) {
    self.status = status
    self.file = file
    self.contentType = contentType
    self.extraHeaders = extraHeaders
  }

  var requests: [HTTPRequest] { lock.withLock { recorded } }

  func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var request = request
    request.path = baseURL.path + (request.path ?? "")
    lock.withLock { recorded.append(request) }
    let url = try #require(Bundle.module.url(forResource: file, withExtension: "json", subdirectory: "Responses"))
    var headers = extraHeaders
    headers[.contentType] = contentType
    return (HTTPResponse(status: status, headerFields: headers), HTTPBody(try Data(contentsOf: url)))
  }
}

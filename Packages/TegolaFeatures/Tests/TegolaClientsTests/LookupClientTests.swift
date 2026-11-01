import CryptoKit
import Dependencies
import DependenciesTestSupport
import Foundation
import HTTPTypes
import Keychain
import OpenAPIRuntime
import SQLiteData
import Synchronization
import TegolaCatalogue
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

/// A server that answers each call from a script, and remembers what it was asked.
final class ScriptedServer: ClientTransport, Sendable {
  struct Answer: Sendable {
    var status: HTTPResponse.Status
    var json: String
    var headers: HTTPFields = [:]
  }

  let answers: Mutex<[String: [Answer]]>
  let requests = Mutex<[(HTTPRequest, Data)]>([])

  init(_ answers: [String: [Answer]]) { self.answers = Mutex(answers) }

  func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String
  ) async throws -> (HTTPResponse, HTTPBody?) {
    var bytes = Data()
    if let body { bytes = try await Data(collecting: body, upTo: 4 * 1024 * 1024) }
    var request = request
    request.path = baseURL.path + (request.path ?? "")
    requests.withLock { $0.append((request, bytes)) }
    let answer = try answers.withLock { answers in
      guard var queue = answers[operationID], !queue.isEmpty else { throw URLError(.cannotConnectToHost) }
      let answer = queue.removeFirst()
      answers[operationID] = queue.isEmpty ? [answer] : queue
      return answer
    }
    var headers = answer.headers
    headers[.contentType] = answer.status == .ok || answer.status == .created ? "application/json" : "application/problem+json"
    return (HTTPResponse(status: answer.status, headerFields: headers), HTTPBody(answer.json))
  }

  var paths: [String] { requests.withLock { $0.map { $0.0.path ?? "" } } }
}

let ridgeRacer = """
  {"candidates": [{
    "releaseID": "igdb:release:1182", "typeID": "video-game", "subtype": "ps1", "title": "Ridge Racer",
    "subtitle": "Namco", "year": 1995, "region": "PAL",
    "fields": {"publisher": "Namco", "catalogueNumber": "SCES-00001", "notAField": "ignored", "media": 3},
    "confidence": 0.97,
    "reasons": [{"kind": "barcode"}, {"kind": "image"}],
    "sources": [{"name": "IGDB", "attribution": "Data from IGDB"}]
  }]}
  """

let problem = #"{"title": "Slow down", "status": 429}"#
let server = URL(string: "https://api.test/v1")!

/// T6.8: the lookup client, over a scripted server (PLAN §7, D-69, D-71, D-73).
@Suite(
  .dependencies {
    $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
    $0.catalogue = try Catalogue.bundled()
  }
)
struct LookupClientTests {
  /// A candidate arrives in the model's terms: the type's own fields, in their kinds; anything else left out.
  @Test func aCandidateIsMappedToTheTypesFields() async throws {
    let scripted = ScriptedServer(["lookupBarcode": [.init(status: .ok, json: ridgeRacer)]])
    let client = LookupClient.live(.init(serverURL: server, debugToken: "dev"), transport: scripted)

    let candidates = try await client.barcode("video-game", "0711719200020", "ps1")

    let candidate = try #require(candidates.first)
    #expect(candidate.values[.title] == .text("Ridge Racer"))
    #expect(candidate.values[.year] == .year(1995))
    #expect(candidate.values[.field("publisher")] == .text("Namco"))
    #expect(candidate.values[.field("notAField")] == nil)
    #expect(candidate.reasons == [.barcode, .image])
    #expect(candidate.strength == .strong)
    #expect(scripted.paths == ["/v1/types/video-game/barcodes/0711719200020?subtype=ps1"])
    // A debug build on a simulator sends the token instead of a signature.
    #expect(scripted.requests.withLock { $0[0].0.headerFields[HTTPField.Name("X-Tegola-Debug-Token")!] } == "dev")
  }

  /// D-71: words alone go as JSON; with a photo, multipart.
  @Test func identifySendsAPhotoAsMultipart() async throws {
    let scripted = ScriptedServer(["identifyObject": [.init(status: .ok, json: ridgeRacer)]])
    let client = LookupClient.live(.init(serverURL: server, debugToken: "dev"), transport: scripted)

    _ = try await client.identify("video-game", LookupHints(title: "Ridge Racer"), nil)
    _ = try await client.identify("video-game", LookupHints(text: "RIDGE RACER"), Data([0xFF, 0xD8, 0xFF, 0xD9]))

    let types = scripted.requests.withLock { $0.map { $0.0.headerFields[.contentType] ?? "" } }
    #expect(types[0].hasPrefix("application/json"))
    #expect(types[1].hasPrefix("multipart/form-data"))
  }

  /// `429` hands the request back to the queue with its wait, never sleeps in the call (PLAN §7).
  @Test func tooManyRequestsAsksToWait() async throws {
    let scripted = ScriptedServer([
      "lookupBarcode": [.init(status: .tooManyRequests, json: problem, headers: [.retryAfter: "30"])]
    ])
    let client = LookupClient.live(.init(serverURL: server, debugToken: "dev"), transport: scripted)

    await #expect(throws: LookupFailure.retryAfter(30)) {
      try await client.barcode("video-game", "0711719200020", nil)
    }
  }

  /// Without a debug token, the first call registers an App Attest key, keeps it, and every call is signed over
  /// the method, the target, the timestamp and the body's hash (contract, security).
  @Test func callsAreSignedWithAnAttestedKey() async throws {
    let scripted = ScriptedServer([
      "getAttestChallenge": [
        .init(status: .ok, json: #"{"challenge": "\#(String(repeating: "c", count: 44))", "expiresAt": "2027-01-15T08:00:00Z"}"#)
      ],
      "registerAttestKey": [.init(status: .created, json: "{}")],
      "lookupBarcode": [.init(status: .ok, json: ridgeRacer)],
    ])
    let assertions = Mutex<[Data]>([])
    try await withDependencies {
      $0.keychain = .inMemory()
      $0.appAttest = AppAttestClient(
        isSupported: { true },
        generateKey: { "key-1" },
        attestKey: { _, _ in Data("attestation".utf8) },
        generateAssertion: { _, hash in
          assertions.withLock { $0.append(hash) }
          return Data("signed".utf8)
        }
      )
    } operation: {
      let client = LookupClient.live(.init(serverURL: server), transport: scripted)
      _ = try await client.barcode("video-game", "0711719200020", nil)
      _ = try await client.barcode("video-game", "0711719200020", nil)

      @Dependency(\.keychain) var keychain
      #expect(try await keychain.load(for: .appAttestKeyID).exposeSecret() == "key-1")
    }

    // Registered once, then two signed lookups.
    #expect(
      scripted.paths == [
        "/v1/app-attest/challenge", "/v1/app-attest/keys",
        "/v1/types/video-game/barcodes/0711719200020", "/v1/types/video-game/barcodes/0711719200020",
      ]
    )
    let (signed, _) = scripted.requests.withLock { $0[2] }
    let timestamp = try #require(signed.headerFields[HTTPField.Name("X-Tegola-Timestamp")!])
    #expect(signed.headerFields[HTTPField.Name("X-Tegola-Key-ID")!] == "key-1")
    #expect(signed.headerFields[HTTPField.Name("X-Tegola-Assertion")!] == Data("signed".utf8).base64EncodedString())
    let emptyHash = SHA256.hash(data: Data()).map { String(format: "%02x", $0) }.joined()
    let message = "GET\n/v1/types/video-game/barcodes/0711719200020\n\(timestamp)\n\(emptyHash)"
    #expect(assertions.withLock { $0.first } == Data(SHA256.hash(data: Data(message.utf8))))
  }
}

/// T6.8's worker over the real queue table (D-73).
@Suite(
  .dependencies {
    $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
    $0.uuid = .incrementing
    $0.calendar = .gregorianUTC
    try $0.bootstrapDatabase()
    let store = ShelfStore(migrated: $0.defaultDatabase, catalogue: try Catalogue.bundled())
    $0.shelf = .store(store)
    $0.lookupQueue = .store(store)
  }
)
struct LookupWorkerTests {
  /// A capture queued with its barcode; returns its id.
  func captured() throws -> ObjectID {
    @Dependency(\.defaultDatabase) var database
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid
    let store = ShelfStore(migrated: database, catalogue: try Catalogue.bundled())
    let draft = ObjectDraft(type: "video-game", subtype: "ps1", values: [.title: .text("Ridge Racer")])
    let context = PlanContext(at: now, source: .capture, catalogue: store.catalogue, makeID: { uuid() })
    return try store.perform(.add(draft, to: .new(name: "Games"), origin: .captured), context: context, lookup: .barcode("0711719200020"))
      .createdObjects[0]
  }

  @Test func anAnswerIsKeptForTheReviewQueue() async throws {
    let id = try captured()
    let candidate = LookupCandidate(
      releaseID: "igdb:1182",
      type: "video-game",
      values: [.title: .text("Ridge Racer")],
      confidence: 0.97,
      reasons: [.barcode],
      sources: [.init(name: "IGDB")]
    )
    let next = try await withDependencies {
      $0.lookup.barcode = { _, _, _ in [candidate] }
    } operation: {
      try await LookupWorker.drain()
    }

    @Dependency(\.lookupQueue) var queue
    let request = try #require(try queue.load().requests.first)
    #expect(request.objectID == id)
    #expect(request.state == .answered)
    #expect(request.answer == [candidate])
    #expect(next == nil)
  }

  @Test func aFailureSpendsAnAttemptAndAWaitDoesnt() async throws {
    _ = try captured()
    let next = try await withDependencies {
      $0.lookup.barcode = { _, _, _ in throw LookupFailure.unavailable }
    } operation: {
      try await LookupWorker.drain()
    }
    @Dependency(\.lookupQueue) var queue
    #expect(try queue.load().requests.map(\.attempts) == [1])
    #expect(next == Date(timeIntervalSince1970: 1_800_000_030))

    try await withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_800_000_030)
      $0.lookup.barcode = { _, _, _ in throw LookupFailure.retryAfter(120) }
    } operation: {
      _ = try await LookupWorker.drain()
    }
    #expect(try queue.load().requests.map(\.attempts) == [1])
  }
}

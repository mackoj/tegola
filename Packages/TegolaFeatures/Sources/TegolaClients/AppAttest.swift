public import Dependencies
import DependenciesMacros
import CryptoKit
public import Foundation
import HTTPTypes
public import Keychain
import OpenAPIRuntime
import TegolaLookupAPI

#if canImport(DeviceCheck)
  import DeviceCheck
#endif

/// Apple's App Attest (PLAN §7): a key that proves calls come from the genuine app on a genuine device. Nothing about
/// the person is in it.
@DependencyClient
public struct AppAttestClient: Sendable {
  public var isSupported: @Sendable () -> Bool = { false }
  /// A new key's id.
  public var generateKey: @Sendable () async throws -> String
  /// The attestation object for a key, over a client data hash.
  public var attestKey: @Sendable (_ keyID: String, _ clientDataHash: Data) async throws -> Data
  /// An assertion over a client data hash.
  public var generateAssertion: @Sendable (_ keyID: String, _ clientDataHash: Data) async throws -> Data
}

extension AppAttestClient: DependencyKey {
  public static var liveValue: AppAttestClient {
    #if canImport(DeviceCheck)
      AppAttestClient(
        isSupported: { DCAppAttestService.shared.isSupported },
        generateKey: { try await DCAppAttestService.shared.generateKey() },
        attestKey: { key, hash in try await DCAppAttestService.shared.attestKey(key, clientDataHash: hash) },
        generateAssertion: { key, hash in
          try await DCAppAttestService.shared.generateAssertion(key, clientDataHash: hash)
        }
      )
    #else
      AppAttestClient()
    #endif
  }

  public static let testValue = AppAttestClient()
}

extension DependencyValues {
  public var appAttest: AppAttestClient {
    get { self[AppAttestClient.self] }
    set { self[AppAttestClient.self] = newValue }
  }
}

extension KeychainKey where Value == String {
  /// The App Attest key id registered with tegola-server. An install's, not a person's.
  public static let appAttestKeyID = KeychainKey("lookup.appAttestKeyID")
}

/// Signs every secured call (contract, security step 2): `X-Tegola-Key-ID`, `X-Tegola-Timestamp` and an assertion over
/// `SHA-256(method + "\n" + path-with-query + "\n" + timestamp + "\n" + SHA-256(body))`. It registers a key on first
/// use, and once more after a `401` naming an unknown key. With a debug token, it sends that instead.
struct AppAttestMiddleware: ClientMiddleware {
  let debugToken: String?
  let register: @Sendable () async throws -> String

  /// The two public calls, made without a signature.
  static let publicOperations: Set<String> = ["getAttestChallenge", "registerAttestKey", "health"]
  /// The most a signed body may be: the identify endpoint's 3 MiB (D-71).
  static let maxBody = 3 * 1024 * 1024

  func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    guard !Self.publicOperations.contains(operationID) else { return try await next(request, body, baseURL) }
    if let debugToken {
      var request = request
      request.headerFields[Self.debugTokenField] = debugToken
      return try await next(request, body, baseURL)
    }
    let bytes: Data? = if let body { try await Data(collecting: body, upTo: Self.maxBody) } else { nil }
    let (response, responseBody) = try await send(request, bytes, baseURL, next)
    guard response.status == .unauthorized else { return (response, responseBody) }
    // A key the server doesn't know: register once more, then retry once. Anything else is the caller's to read.
    var problem = Data()
    if let responseBody { problem = try await Data(collecting: responseBody, upTo: 64 * 1024) }
    guard String(decoding: problem, as: UTF8.self).contains("unknown-key") else {
      return (response, HTTPBody(problem))
    }
    @Dependency(\.keychain) var keychain
    try await keychain.delete(for: .appAttestKeyID)
    return try await send(request, bytes, baseURL, next)
  }

  func send(
    _ request: HTTPRequest,
    _ bytes: Data?,
    _ baseURL: URL,
    _ next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    @Dependency(\.appAttest) var appAttest
    @Dependency(\.date.now) var now
    let keyID = try await currentKey()
    let timestamp = now.formatted(.iso8601)
    var request = request
    let message = Self.message(
      method: request.method.rawValue,
      target: baseURL.path + (request.path ?? ""),
      timestamp: timestamp,
      body: bytes ?? Data()
    )
    let assertion = try await appAttest.generateAssertion(keyID, Data(SHA256.hash(data: message)))
    request.headerFields[Self.keyIDField] = keyID
    request.headerFields[Self.timestampField] = timestamp
    request.headerFields[Self.assertionField] = assertion.base64EncodedString()
    return try await next(request, bytes.map { HTTPBody($0) }, baseURL)
  }

  /// The key in the keychain, or a new one registered now.
  func currentKey() async throws -> String {
    @Dependency(\.keychain) var keychain
    if let saved = try await keychain.loadIfPresent(for: .appAttestKeyID) {
      // exposeSecret: the header carries the key id.
      return saved.exposeSecret()
    }
    let keyID = try await register()
    try await keychain.save(Secret(keyID), for: .appAttestKeyID)
    return keyID
  }

  /// The bytes the assertion covers (contract, security step 2).
  static func message(method: String, target: String, timestamp: String, body: Data) -> Data {
    let bodyHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
    return Data("\(method.uppercased())\n\(target)\n\(timestamp)\n\(bodyHash)".utf8)
  }

  /// Registers a new key: a challenge, `attestKey` over its hash, then `POST /app-attest/keys` (security step 1).
  static func register(with client: Client) async throws -> String {
    @Dependency(\.appAttest) var appAttest
    guard appAttest.isSupported() else { throw LookupFailure.rejected(status: 401) }
    let challenge = try await client.getAttestChallenge().ok.body.json.challenge
    let keyID = try await appAttest.generateKey()
    let attestation = try await appAttest.attestKey(keyID, Data(SHA256.hash(data: Data(challenge.utf8))))
    _ = try await client.registerAttestKey(
      body: .json(.init(keyID: keyID, attestation: attestation.base64EncodedString(), challenge: challenge))
    ).created
    return keyID
  }

  static let keyIDField = HTTPField.Name("X-Tegola-Key-ID")!
  static let timestampField = HTTPField.Name("X-Tegola-Timestamp")!
  static let assertionField = HTTPField.Name("X-Tegola-Assertion")!
  static let debugTokenField = HTTPField.Name("X-Tegola-Debug-Token")!
}

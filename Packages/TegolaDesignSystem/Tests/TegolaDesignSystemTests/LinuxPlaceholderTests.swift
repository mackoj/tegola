import Testing

/// Keeps this test target non-empty where SwiftUI isn't available (Linux), so `swift test` runs everywhere.
@Suite struct DesignSystemBuilds {
  @Test func builds() {}
}

import Foundation
import Testing

@testable import TegolaModel

/// T8.5: analytics events carry shape, never content.
@Suite struct AnalyticsTests {
  @Test func countsAreBucketed() {
    #expect([0, 1, 4, 12, 50, 485].map(AnalyticsEvent.Bucket.init) == [.none, .one, .few, .some, .many, .lots])
  }

  /// The taxonomy's v1 names, as `05_Tagging and Metrics` spells them, including the two F17 asks for.
  @Test func theNamesAreTheTaxonomys() {
    let names = Set(AnalyticsEvent.Name.allCases.map(\.rawValue))
    #expect(names.contains("object_flagged_sellable"))
    #expect(names.contains("wish_added"))
    #expect(names.allSatisfy { $0.allSatisfy { $0.isLowercase || $0 == "_" } })
  }

  @Test func anEventRoundTripsAsJSON() throws {
    let event = AnalyticsEvent(
      .importCompleted,
      at: Date(timeIntervalSince1970: 1_800_000_000),
      [.rowsBucket: .bucket(.lots), .matchedPctBucket: .bucket(.many), .format: .word(.csv)]
    )
    let decoded = try JSONDecoder().decode(AnalyticsEvent.self, from: JSONEncoder().encode(event))
    #expect(decoded == event)
  }
}

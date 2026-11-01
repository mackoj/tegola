import Foundation
import TegolaModel
import Testing

@testable import ShelfViews

/// T7.2: a return's history line names the person and says it was closed one-sided (D-3, PD-160, F13).
@Suite struct HistoryLineTests {
  @Test func aReturnNamesThePersonAndSaysItWasOneSided() {
    #expect(ShelfEvent.returnLine(from: "Dara", cameBack: nil, words: nil) == "Back from Dara, closed by you")
    #expect(
      ShelfEvent.returnLine(from: "Dara", cameBack: .damaged, words: "Sleeve torn")
        == "Back from Dara, closed by you · damaged · Sleeve torn"
    )
    #expect(
      ShelfEvent.returnLine(from: "Elsa", cameBack: .somethingMissing, words: nil)
        == "Back from Elsa, closed by you · something missing"
    )
  }
}

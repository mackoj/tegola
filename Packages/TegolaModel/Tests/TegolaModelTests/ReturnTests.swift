import Foundation
import TegolaCatalogue
import Testing

@testable import TegolaModel

/// T7.2: how a loan came back (board 20, PD-148), closed one-sided (PD-160).
@Suite struct ReturnTests {
  @Test func aBlankNoteIsNoNote() throws {
    var harness = Harness()
    let id = try harness.add()
    try harness.perform(.lend(id, to: .new(name: "Dara"), due: nil, note: ""))
    let loan = try #require(harness.shelf.openLoan(on: id))
    try harness.perform(.returnLoan(loan.id, cameBack: .sameShape, condition: "  \n"))
    #expect(harness.shelf.loans[loan.id]?.returnCondition == nil)
    #expect(harness.shelf.loans[loan.id]?.cameBack == .sameShape)
  }

  @Test func sayingNothingAboutTheReturnIsAllowed() throws {
    var harness = Harness()
    let id = try harness.add()
    try harness.perform(.lend(id, to: .new(name: "Dara"), due: nil, note: ""))
    let loan = try #require(harness.shelf.openLoan(on: id))
    try harness.perform(.returnLoan(loan.id, condition: nil))
    #expect(harness.shelf.loans[loan.id]?.cameBack == nil)
    #expect(harness.shelf.loans[loan.id]?.isOneSided == true)
  }

  /// Events written before T7.2 have no `cameBack`; they still decode, and replay to the same loan.
  @Test func aReturnWrittenBeforeM7StillDecodes() throws {
    let loanID = LoanID(UUID())
    let objectID = ObjectID(UUID())
    let event = ShelfEvent.Kind.returned(loanID, objectID: objectID, condition: "Fine", cameBack: .damaged)
    let encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: [String: Any]]
    )
    var returned = try #require(encoded["returned"])
    #expect(returned["cameBack"] as? String == "damaged")
    returned["cameBack"] = nil
    let old = try JSONSerialization.data(withJSONObject: ["returned": returned])
    let decoded = try JSONDecoder().decode(ShelfEvent.Kind.self, from: old)
    #expect(decoded == .returned(loanID, objectID: objectID, condition: "Fine", cameBack: nil))
  }
}

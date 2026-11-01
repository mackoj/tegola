import ComposableArchitecture
import DependenciesTestSupport
import FeatureTestSupport
import Foundation
import SQLiteData
import TegolaClients
import TegolaModel
import TegolaStorage
import Testing

@testable import ReturnFeature

func shelfNow() throws -> Shelf {
  @Dependency(\.defaultDatabase) var database
  return try database.read { db in try ShelfRequest().fetch(db).shelf }
}

@MainActor
@Suite(.dependencies { try $0.seededShelf() })
struct ReturnFeatureTests {
  /// The seed lends Kid A to Max with no date.
  func store() throws -> (TestStoreOf<ReturnFeature>, LoanID) {
    let shelf = try shelfNow()
    let kidA = try #require(shelf.objects.values.first { $0.title == "Kid A" })
    let loan = try #require(shelf.openLoan(on: kidA.id))
    let state = try #require(ReturnFeature.State(loan: loan.id, shelf: shelf, now: testNow, calendar: .testUTC))
    let store = TestStore(initialState: state) { ReturnFeature() } withDependencies: {
      $0.dismiss = DismissEffect {}
    }
    return (store, loan.id)
  }

  @Test func theSheetKnowsWhoHadItAndStartsOnTheSameShape() throws {
    let (store, _) = try store()
    #expect(store.state.nudge.title == "Kid A")
    #expect(store.state.nudge.person == "Max")
    #expect(store.state.nudge.daysOverdue == nil)
    #expect(store.state.cameBack == .sameShape)
  }

  /// F13, board 20: how it came back and the note go into history; the loan is closed one-sided.
  @Test func itsHomeClosesTheLoanWithHowItCameBack() async throws {
    let (store, loanID) = try store()
    await store.send(.view(.cameBackTapped(.damaged))) { $0.cameBack = .damaged }
    await store.send(.view(.noteChanged(" Sleeve torn "))) { $0.note = " Sleeve torn " }
    #expect(store.state.words == "Sleeve torn")
    await store.send(.view(.itsHomeTapped))
    await store.receive(\.succeeded)

    let loan = try #require(try shelfNow().loans[loanID])
    #expect(!loan.isOpen)
    #expect(loan.isOneSided)
    #expect(loan.cameBack == .damaged)
    #expect(loan.returnCondition == "Sleeve torn")
  }

  @Test func tappingTheChosenAnswerAgainLeavesItUnsaid() async throws {
    let (store, loanID) = try store()
    await store.send(.view(.cameBackTapped(.sameShape))) { $0.cameBack = nil }
    await store.send(.view(.itsHomeTapped))
    await store.receive(\.succeeded)
    #expect(try shelfNow().loans[loanID]?.cameBack == nil)
  }

  @Test func cancelWritesNothing() async throws {
    let (store, loanID) = try store()
    await store.send(.view(.cancelTapped))
    #expect(try shelfNow().loans[loanID]?.isOpen == true)
  }

  @Test func aLoanThatIsntOutHasNoSheet() throws {
    let shelf = try shelfNow()
    let borrowed = try #require(shelf.objects.values.first { $0.title == "Root" })
    let loan = try #require(shelf.openLoan(on: borrowed.id))
    #expect(ReturnFeature.State(loan: loan.id, shelf: shelf, now: testNow, calendar: .testUTC) == nil)
  }
}

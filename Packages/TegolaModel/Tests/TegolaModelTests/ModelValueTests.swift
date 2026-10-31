import Foundation
import Testing

@testable import TegolaModel

@Suite struct MoneyTests {
  let eur = Currency("EUR")!
  let gbp = Currency("GBP")!

  @Test func currencyMustBeThreeUppercaseLetters() {
    #expect(Currency("EUR") != nil)
    #expect(Currency("eur") == nil)
    #expect(Currency("EURO") == nil)
  }

  @Test func totalsNeverMixCurrencies() {
    let totals = Money.totals([
      Money(minorUnits: 3800, currency: eur), Money(minorUnits: 1200, currency: gbp),
      Money(minorUnits: 200, currency: eur),
    ])
    #expect(totals == [Money(minorUnits: 4000, currency: eur), Money(minorUnits: 1200, currency: gbp)])
  }

  @Test func roundTripsThroughJSON() throws {
    let money = Money(minorUnits: 4800, currency: eur)
    let decoded = try JSONDecoder().decode(Money.self, from: JSONEncoder().encode(money))
    #expect(decoded == money)
  }
}

@Suite struct PlacePathTests {
  /// PLAN §2.9 F10, first half (the Places screen joins in M7).
  @Test func typingAPathGivesNestedPlaces() throws {
    let path = try #require(PlacePath(typed: "Cellar › Rack 3 › Bin 12"))
    #expect(path.components == ["Cellar", "Rack 3", "Bin 12"])
    #expect(path.lineage.map(\.description) == ["Cellar", "Cellar › Rack 3", "Cellar › Rack 3 › Bin 12"])
    #expect(path.name == "Bin 12")
  }

  @Test(arguments: ["Cellar > Rack 3", "Cellar/Rack 3", "  Cellar ›› Rack 3  ", "Cellar › › Rack 3"])
  func otherSeparatorsAndStraySpacesReadTheSame(_ typed: String) {
    #expect(PlacePath(typed: typed)?.description == "Cellar › Rack 3")
  }

  @Test func blankIsNoPlace() {
    #expect(PlacePath(typed: "  ›  ") == nil)
  }

  @Test(arguments: ["Cellar › Rack 3", "Living room", "Loft › Box 12 › Left"])
  func printingAndReadingAgainGivesTheSamePath(_ typed: String) throws {
    let path = try #require(PlacePath(typed: typed))
    #expect(PlacePath(typed: path.description) == path)
  }

  @Test func nearDuplicatesAreCaught() {
    #expect(PlacePath.isNearDuplicate("Rack 3", "rack3"))
    #expect(PlacePath.isNearDuplicate("Living room", "Livng room"))
    #expect(!PlacePath.isNearDuplicate("Rack 3", "Rack 4 left"))
    #expect(!PlacePath.isNearDuplicate("Loft", "Cellar"))
  }
}

@Suite struct ObjectStatusTests {
  @Test func onlyWatchAndActNeedAttention() {
    #expect(ObjectStatus.allCases.filter(\.needsAttention) == [.watch, .act])
  }

  @Test func sortsMostUrgentFirst() {
    #expect(ObjectStatus.allCases.sorted() == [.act, .watch, .good, .fine, .gone])
  }
}

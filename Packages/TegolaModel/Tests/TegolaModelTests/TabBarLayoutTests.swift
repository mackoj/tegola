import Foundation
import Testing

@testable import TegolaModel

@Suite struct TabBarLayoutTests {
  @Test func defaultIsShelfFindScanActivityYou() {
    #expect(TabBarLayout.default.order == [.shelf, .find, .scan, .activity, .you])
  }

  @Test func onlyScanPresents() {
    #expect(AppTab.allCases.filter(\.presents) == [.scan])
  }

  @Test func movingKeepsShelfAndScanInPlace() {
    var layout = TabBarLayout.default
    layout.move(.you, toMovablePosition: 0)
    #expect(layout.order == [.shelf, .you, .scan, .find, .activity])
  }

  @Test func fixedTabsCannotMove() {
    var layout = TabBarLayout.default
    layout.move(.scan, toMovablePosition: 0)
    layout.move(.shelf, toMovablePosition: 2)
    #expect(layout == .default)
  }

  @Test func noTabCanBeHiddenOrRepeated() {
    #expect(TabBarLayout(movable: [.find, .activity]) == nil)
    #expect(TabBarLayout(movable: [.find, .find, .you]) == nil)
    #expect(TabBarLayout(movable: [.find, .scan, .you]) == nil)
  }

  @Test func aStoredOrderThatBreaksTheRulesFallsBackToTheDefault() throws {
    let stored = try JSONEncoder().encode(["find", "shelf", "scan", "activity", "you"])
    #expect(try JSONDecoder().decode(TabBarLayout.self, from: stored) == .default)
    let renamed = try JSONEncoder().encode(["shelf", "search", "scan", "activity", "you"])
    #expect(try JSONDecoder().decode(TabBarLayout.self, from: renamed) == .default)
    #expect(try JSONDecoder().decode(TabBarLayout.self, from: Data("42".utf8)) == .default)
    var layout = TabBarLayout.default
    layout.move(.activity, toMovablePosition: 0)
    #expect(try JSONDecoder().decode(TabBarLayout.self, from: JSONEncoder().encode(layout)) == layout)
  }
}

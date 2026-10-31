import XCTest

/// The shell reaches every tab, and Scan presents the add sheet rather than selecting (PD-117). The journeys (PLAN §4.4) join as
/// their screens are built.
final class AppShellUITests: XCTestCase {
  @MainActor
  func testEveryTabIsReachableAndScanPresents() {
    let app = XCUIApplication()
    app.launchArguments = ["--reset", "-AppleLanguages", "(en)"]
    app.launch()

    for tab in ["find", "activity", "you", "shelf"] {
      app.buttons["tab.\(tab)"].tap()
    }
    app.buttons["tab.scan"].tap()
    XCTAssertTrue(app.buttons["add.type.music"].waitForExistence(timeout: 2))
  }
}

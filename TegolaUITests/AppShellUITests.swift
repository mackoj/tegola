import XCTest

/// The shell reaches every tab, and Scan presents the camera rather than selecting (PD-117). The journeys (PLAN §4.4) join as
/// their screens are built.
final class AppShellUITests: XCTestCase {
  @MainActor
  func testEveryTabIsReachableAndScanPresents() {
    let app = XCUIApplication()
    app.launchArguments = ["--reset", "-AppleLanguages", "(en)"]
    app.launch()

    // An empty shelf opens on the first piece; looking around first leaves it.
    app.buttons["firstPiece.lookAround"].tap()
    for tab in ["find", "activity", "you", "shelf"] {
      app.buttons["tab.\(tab)"].tap()
    }
    app.buttons["tab.scan"].tap()
    XCTAssertTrue(app.buttons["capture.type.music"].waitForExistence(timeout: 2))
  }
}

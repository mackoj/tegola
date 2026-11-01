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
    for tab in ["Find", "Activity", "You", "Shelf"] {
      app.tab(tab).tap()
      XCTAssertTrue(app.tab(tab).isSelected, "\(tab) is selected")
    }
    app.tab("Scan").tap()
    XCTAssertTrue(app.buttons["capture.type.music"].waitForExistence(timeout: 2))
  }
}

extension XCUIApplication {
  /// A tab in the system tab bar, by its English label (the tests launch in English; D-77).
  func tab(_ label: String) -> XCUIElement { tabBars.buttons[label] }
}

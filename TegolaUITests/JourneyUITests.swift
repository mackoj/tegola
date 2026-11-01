import XCTest

/// The journeys (PLAN §4.4) that M3's screens can carry, from a cold launch with `--reset` and no `--screen`
/// shortcut. Each journey joins in full as its screens arrive.
final class JourneyUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
    app.launch()
    return app
  }

  /// Types a title into the add sheet's form and saves.
  func addTitle(_ title: String, andAnother: Bool, in app: XCUIApplication) {
    let field = app.textFields["edit.title"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText(title)
    app.buttons[andAnother ? "add.saveAnother" : "add.save"].tap()
  }

  /// Journey 1, the first evening, as far as M3 goes: the first object typed by hand on the empty shelf (the
  /// first-piece camera is M5), a second one, then a place set through Edit, which shows in the object's history.
  /// The photo beat needs the system photo picker, which a UI test can't drive; it joins with M6's scripted camera.
  @MainActor
  func testTheFirstEvening() {
    let app = launch()
    app.buttons["shelf.typeIt"].tap()
    app.buttons["add.type.music"].tap()
    addTitle("Kid A", andAnother: true, in: app)
    XCTAssertTrue(app.staticTexts["add.count"].waitForExistence(timeout: 5))
    addTitle("Homogenic", andAnother: false, in: app)

    // The first object of a type made its collection.
    let collection = app.buttons["shelf.collection.My Music"]
    XCTAssertTrue(collection.waitForExistence(timeout: 5))
    collection.tap()
    app.buttons["collection.object.Kid A"].tap()
    XCTAssertTrue(app.staticTexts["object.title"].waitForExistence(timeout: 5))

    // A place, typed as a path.
    app.buttons["object.edit"].tap()
    let place = app.textFields["edit.place"]
    XCTAssertTrue(place.waitForExistence(timeout: 5))
    place.tap()
    place.typeText("Living room › Record shelf")
    app.buttons["modal.save"].tap()
    XCTAssertTrue(app.staticTexts["Placed · Living room › Record shelf"].waitForExistence(timeout: 5))
  }

  /// Journey 5, the weekly glance (PLAN §4.4, F15): the Today strip says one thing needs attention; it's a Game Boy
  /// cartridge whose save battery is due; logging a swap clears it, and the line is gone.
  @MainActor
  func testTheWeeklyGlance() {
    let app = XCUIApplication()
    app.launchArguments = ["--reset", "--seed", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
    app.launch()
    let line = app.buttons["today.needAttention"].firstMatch
    XCTAssertTrue(line.waitForExistence(timeout: 10))
    XCTAssertTrue(line.label.contains("1 needs attention"), line.label)
    line.tap()

    let row = app.descendants(matching: .any)["signals.row.Tetris"].firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 5))
    row.tap()
    XCTAssertTrue(app.staticTexts["signal.estimate"].firstMatch.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["signal.reason.saveBattery"].exists)

    app.buttons["object.remedy.batterySwap"].firstMatch.tap()
    XCTAssertTrue(app.staticTexts["Serviced"].firstMatch.waitForExistence(timeout: 5))

    // Back to the shelf: tapping the tab you're on returns to its root.
    app.buttons["tab.shelf"].tap()
    XCTAssertTrue(app.staticTexts["2 to tidy"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["today.needAttention"].firstMatch.exists)
  }

  /// M3's exit test, automated: thirty objects across Video games and Thing in one sitting, without a hint (page 52,
  /// P1). The test with people is the owner's to run; this proves the path has no dead end.
  @MainActor
  func testThirtyObjectsInOneSitting() {
    let app = launch()
    app.buttons["tab.scan"].tap()
    app.buttons["add.type.video-game"].tap()
    for n in 1...15 { addTitle("Game \(n)", andAnother: true, in: app) }
    app.buttons["modal.dismiss"].tap()
    app.buttons["tab.scan"].tap()
    app.buttons["add.type.thing"].tap()
    for n in 1...14 { addTitle("Thing \(n)", andAnother: true, in: app) }
    addTitle("Thing 15", andAnother: false, in: app)
    XCTAssertTrue(app.staticTexts["30 objects"].waitForExistence(timeout: 5))
  }
}

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

  /// Journey 1, the first evening (PLAN F2, T5.8): the app opens on the first piece; it's typed, named a record, given
  /// its story, and lands in a collection the collector never made. One at a time opens Scan for the second; then a
  /// place set through Edit shows in the object's history. The camera beat needs a real camera, which the simulator
  /// hasn't got; it joins with M6's scripted camera.
  @MainActor
  func testTheFirstEvening() {
    let app = launch()
    let typeIt = app.buttons["firstPiece.typeIt"]
    XCTAssertTrue(typeIt.waitForExistence(timeout: 5))
    typeIt.tap()
    let name = app.textFields["firstPiece.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["firstPiece.next"].isEnabled)
    name.tap()
    name.typeText("Kid A")
    app.buttons["firstPiece.type.music"].tap()
    app.buttons["firstPiece.next"].tap()
    app.buttons["firstPiece.story.gift"].tap()
    app.buttons["firstPiece.save"].tap()
    // The payoff: a record has no clock, so it's the story.
    XCTAssertTrue(app.staticTexts["firstPiece.payoff.story"].waitForExistence(timeout: 5))
    app.buttons["firstPiece.oneAtATime"].tap()

    // One at a time opens Scan's camera; the simulator has none, so it's typed.
    let typeItInScan = app.buttons["capture.typeIt"]
    XCTAssertTrue(typeItInScan.waitForExistence(timeout: 5))
    typeItInScan.tap()
    let music = app.buttons["add.type.music"]
    XCTAssertTrue(music.waitForExistence(timeout: 5))
    music.tap()
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

  /// Journey 2, *Bring your list* (PLAN F9, T6.12): the owner's `Jeux collection.csv` becomes one sentence, a shelf
  /// in one write, and a payoff that can be undone. `--import-fixture` stands for the file picker, which a UI test
  /// can't drive. Matching needs tegola-server, which the simulator doesn't reach: the rows stay as written.
  @MainActor
  func testBringYourList() {
    let fixture = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .appending(path: "Packages/TegolaTestSupport/Sources/TegolaFixtures/Fixtures/Jeux collection.csv").path
    let app = XCUIApplication()
    app.launchArguments = [
      // The seed shelf: an empty one would open on the first piece, and a sheet can't open over that cover.
      "--reset", "--seed", "--import-fixture", fixture, "-AppleLanguages", "(en)", "-AppleLocale", "en_GB",
    ]
    app.launch()
    let sentence = app.staticTexts["import.sentence"]
    XCTAssertTrue(sentence.waitForExistence(timeout: 15))
    XCTAssertTrue(sentence.label.hasPrefix("485 games on 20 shelves"))
    app.buttons["import.build"].tap()
    XCTAssertTrue(app.staticTexts["import.payoff.count"].waitForExistence(timeout: 30))
    app.buttons["import.done"].tap()
    // Done opens the collection the rows landed in.
    XCTAssertTrue(app.buttons["collection.rename"].waitForExistence(timeout: 10))
  }

  /// F6 (T6.9): Scan's camera saves a shot at once and keeps going; the object waits in the tray. The simulator has no
  /// camera, so the shot is saved from nothing read, as an object that needs details.
  @MainActor
  func testAShotSavesBeforeAnyNetwork() {
    let app = XCUIApplication()
    app.launchArguments = ["--reset", "--seed", "-AppleLanguages", "(en)", "-AppleLocale", "en_GB"]
    app.launch()
    app.buttons["tab.scan"].tap()
    app.buttons["capture.type.video-game"].tap()
    let shutter = app.buttons["capture.shutter"]
    XCTAssertTrue(shutter.waitForExistence(timeout: 5) && shutter.isHittable)
    shutter.tap()
    XCTAssertTrue(app.staticTexts["capture.trayCount"].waitForExistence(timeout: 5))
    app.buttons["capture.shutter"].tap()
    XCTAssertTrue(app.staticTexts["2 saved"].waitForExistence(timeout: 5))
  }

  /// M3's exit test, automated: thirty objects across Video games and Thing in one sitting, without a hint (page 52,
  /// P1). The test with people is the owner's to run; this proves the path has no dead end.
  @MainActor
  func testThirtyObjectsInOneSitting() {
    let app = launch()
    app.buttons["firstPiece.lookAround"].tap()
    app.buttons["tab.scan"].tap()
    app.buttons["capture.typeIt"].tap()
    XCTAssertTrue(app.buttons["add.type.video-game"].waitForExistence(timeout: 5))
    app.buttons["add.type.video-game"].tap()
    for n in 1...15 { addTitle("Game \(n)", andAnother: true, in: app) }
    app.buttons["modal.dismiss"].tap()
    app.buttons["tab.scan"].tap()
    app.buttons["capture.typeIt"].tap()
    XCTAssertTrue(app.buttons["add.type.thing"].waitForExistence(timeout: 5))
    app.buttons["add.type.thing"].tap()
    for n in 1...14 { addTitle("Thing \(n)", andAnother: true, in: app) }
    addTitle("Thing 15", andAnother: false, in: app)
    XCTAssertTrue(app.staticTexts["30 objects"].waitForExistence(timeout: 5))
  }
}

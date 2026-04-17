import XCTest

final class AppLaunchTests: XCTestCase {
    func test_appLaunchesIntoSetupFlowWhenNoSessionIsPersisted() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-session"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Connect"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Connect"].exists)
    }

    func test_fixtureBackedSessionShowsSeededLibraryCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-library-fixture"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Library"].exists)
        XCTAssertTrue(app.tabBars.buttons["Add"].exists)
        XCTAssertFalse(app.tabBars.buttons["Settings"].exists)
        XCTAssertTrue(app.buttons["server-status-pill"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["library-card-title-1"].waitForExistence(timeout: 10))
    }

    func test_libraryShowsCompactControlBarAndPosterCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-library-fixture"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["library-control-bar"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["server-status-pill"].exists)
        XCTAssertTrue(app.staticTexts["library-card-title-1"].waitForExistence(timeout: 10))
    }
}

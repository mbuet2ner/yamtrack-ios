import XCTest

@MainActor
final class AppLaunchTests: XCTestCase {
    func test_appLaunchesIntoSetupFlowWhenNoSessionIsPersisted() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-session"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Connect"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["setup-connect-button"].exists)
    }

    func test_fixtureBackedSessionShowsSeededLibraryCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-library-fixture"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["server-status-pill"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["library-add-media-button"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["library-card-title-1"].waitForExistence(timeout: 10))
    }

    func test_libraryShowsCompactControlBarAndPosterCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-library-fixture"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["library-filter-control"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["server-status-pill"].exists)
        XCTAssertTrue(app.buttons["library-add-media-button"].exists)
        XCTAssertTrue(app.staticTexts["library-card-title-1"].waitForExistence(timeout: 10))
    }
}

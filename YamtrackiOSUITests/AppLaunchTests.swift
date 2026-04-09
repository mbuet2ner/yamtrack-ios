import XCTest

final class AppLaunchTests: XCTestCase {
    func test_appLaunchesIntoSetupFlowWhenNoSessionIsPersisted() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-session"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Connect"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Connect"].exists)
    }
}

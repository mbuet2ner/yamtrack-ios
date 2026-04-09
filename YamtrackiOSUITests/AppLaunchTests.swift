import XCTest

final class AppLaunchTests: XCTestCase {
    func test_appLaunchesIntoRootShell() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Library"].exists)
        XCTAssertTrue(app.buttons["Search"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
    }
}

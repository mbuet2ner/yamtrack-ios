import XCTest

final class AppLaunchTests: XCTestCase {
    func test_appLaunchesIntoRootShell() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 2))
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["Library"].exists)
        XCTAssertTrue(tabBar.buttons["Search"].exists)
        XCTAssertTrue(tabBar.buttons["Settings"].exists)
    }
}

import XCTest

final class SetupFlowUITests: XCTestCase {
    func test_signedInLaunchShowsTabShell() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 2))
        XCTAssertTrue(tabBar.buttons["Library"].exists)
        XCTAssertTrue(tabBar.buttons["Search"].exists)
        XCTAssertTrue(tabBar.buttons["Settings"].exists)
        XCTAssertFalse(app.navigationBars["Connect"].exists)
    }

    func test_invalidCredentialsShowError() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-session", "-ui-testing-invalid-auth"]
        app.launch()

        let connectButton = app.buttons["Connect"]
        let serverField = app.textFields["Server URL"]
        let tokenField = app.secureTextFields["API Token"]

        XCTAssertTrue(serverField.waitForExistence(timeout: 2))
        serverField.tap()
        serverField.typeText("https://demo.local")
        tokenField.tap()
        tokenField.typeText("bad-token")
        connectButton.tap()

        XCTAssertTrue(app.staticTexts["Invalid token"].waitForExistence(timeout: 2))
    }

    func test_settingsAllowsLogoutBackToConnect() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session"]
        app.launch()

        app.tabBars.firstMatch.buttons["Settings"].tap()

        XCTAssertTrue(app.otherElements["settings-connection-card"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["settings-actions-card"].exists)
        let logoutButton = app.buttons["Log Out"]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 2))
        logoutButton.tap()

        XCTAssertTrue(app.navigationBars["Connect"].waitForExistence(timeout: 2))
    }
}

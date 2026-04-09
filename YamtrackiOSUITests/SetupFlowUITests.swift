import XCTest

final class SetupFlowUITests: XCTestCase {
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
}

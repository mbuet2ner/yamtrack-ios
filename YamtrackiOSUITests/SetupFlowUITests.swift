import XCTest

final class SetupFlowUITests: XCTestCase {
    func test_signedInLaunchShowsTabShell() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 2))
        XCTAssertTrue(tabBar.buttons["Library"].exists)
        XCTAssertFalse(tabBar.buttons["Search"].exists)
        XCTAssertTrue(tabBar.buttons["Settings"].exists)
        XCTAssertTrue(app.navigationBars.buttons["Add Media"].waitForExistence(timeout: 2))
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

    func test_addTabEmptyResultsUsesSingleEmptyStateMessage() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-library-fixture"]
        app.launch()

        app.tabBars.firstMatch.buttons["Add"].tap()

        XCTAssertTrue(app.navigationBars["Add Media"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Search for something to add."].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Artwork, provider, and selection state appear here."].exists)
    }

    func test_bookBarcodeScanAddsFixtureBookToLibrary() {
        let isbn = "9780306406157"
        let app = launchAddMediaApp(simulatedBookISBN: isbn)

        openBookAddMedia(in: app)
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 2))

        XCTAssertTrue(scrollUntilExists(app.staticTexts["Ready To Add"], in: scrollView))
        XCTAssertTrue(app.staticTexts["Das Glasperlenspiel"].exists)
        app.buttons["add-media-confirm-button"].tap()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Das Glasperlenspiel"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["library-card-2"].waitForExistence(timeout: 3))
    }

    func test_bookBarcodeNoMatchFallbackPrefillsISBNInSearchField() {
        let isbn = "9780140449136"
        let app = launchAddMediaApp(simulatedBookISBN: isbn)

        openBookAddMedia(in: app)
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 2))

        XCTAssertTrue(scrollUntilExists(app.staticTexts["No barcode match found."], in: scrollView))
        XCTAssertTrue(scrollUntilExists(app.buttons["add-media-barcode-fallback-button"], in: scrollView))
        app.buttons["add-media-barcode-fallback-button"].tap()

        let searchField = app.textFields["add-media-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        XCTAssertEqual(searchField.value as? String, isbn)
    }

    private func launchAddMediaApp(simulatedBookISBN: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-persisted-session",
            "-ui-testing-library-fixture",
            "-ui-testing-simulated-book-isbn",
            simulatedBookISBN
        ]
        app.launch()
        return app
    }

    private func openBookAddMedia(in app: XCUIApplication) {
        app.tabBars.firstMatch.buttons["Add"].tap()
        XCTAssertTrue(app.navigationBars["Add Media"].waitForExistence(timeout: 2))
        app.buttons["Book"].tap()
    }

    private func scrollUntilExists(_ element: XCUIElement, in scrollView: XCUIElement, maxSwipes: Int = 6) -> Bool {
        for _ in 0..<maxSwipes {
            if element.waitForExistence(timeout: 0.5) {
                return true
            }
            scrollView.swipeUp()
        }

        return element.waitForExistence(timeout: 1)
    }
}

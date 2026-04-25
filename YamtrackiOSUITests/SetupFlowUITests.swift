import XCTest

@MainActor
final class SetupFlowUITests: XCTestCase {
    func test_signedInLaunchShowsTabShell() {
        let app = makeFixtureApp()

        assertLibraryShell(in: app)
        XCTAssertTrue(app.buttons["server-status-pill"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["library-filter-control"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Connect"].exists)
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

        XCTAssertTrue(app.staticTexts["Invalid token"].waitForExistence(timeout: 5))
    }

    func test_disconnectedLaunchShowsLibraryShellAndCanOpenConnectionSheet() {
        let app = makeDisconnectedApp()

        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 5))
        let disconnectedPill = app.buttons["server-status-pill"]
        XCTAssertTrue(disconnectedPill.waitForExistence(timeout: 5))
        XCTAssertEqual(disconnectedPill.label, "Disconnected")

        app.buttons["Open Connection Settings"].tap()

        XCTAssertTrue(app.staticTexts["Connection"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["setup-connect-button"].exists)
    }

    func test_connectedLaunchConnectionSheetReconnectsAndUpdatesServerPill() {
        let app = makeFixtureApp()

        let pillButton = app.buttons["server-status-pill"]
        XCTAssertTrue(pillButton.waitForExistence(timeout: 2))
        XCTAssertEqual(pillButton.label, "demo.local")
        pillButton.tap()

        XCTAssertTrue(app.staticTexts["Connection"].waitForExistence(timeout: 2))

        let serverField = app.textFields["Server URL"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 2))
        replaceText(in: serverField, with: "https://second.local")
        app.secureTextFields["API Token"].tap()

        let connectButton = app.buttons["setup-connect-button"]
        XCTAssertTrue(connectButton.isEnabled)
        connectButton.tap()

        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Connection"].exists)
        let updatedPill = app.buttons["server-status-pill"]
        XCTAssertTrue(updatedPill.waitForExistence(timeout: 5))
        XCTAssertEqual(updatedPill.label, "second.local")
    }

    func test_connectedLaunchFailedReconnectKeepsOriginalServerPill() {
        let app = makeFixtureApp()

        let pillButton = app.buttons["server-status-pill"]
        XCTAssertTrue(pillButton.waitForExistence(timeout: 2))
        XCTAssertEqual(pillButton.label, "demo.local")
        pillButton.tap()

        XCTAssertTrue(app.staticTexts["Connection"].waitForExistence(timeout: 2))

        let serverField = app.textFields["Server URL"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 2))
        replaceText(in: serverField, with: "not-a-url")
        app.secureTextFields["API Token"].tap()

        let connectButton = app.buttons["setup-connect-button"]
        XCTAssertTrue(connectButton.isEnabled)
        connectButton.tap()

        XCTAssertTrue(app.staticTexts["Invalid server URL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Connection"].exists)

        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 5))
        let unchangedPill = app.buttons["server-status-pill"]
        XCTAssertTrue(unchangedPill.waitForExistence(timeout: 5))
        XCTAssertEqual(unchangedPill.label, "demo.local")
    }

    func test_restoredSessionWithExpiredLibraryAuthShowsDisconnectedRecoveryPill() {
        let app = makeExpiredAuthFixtureApp()

        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 5))

        let disconnectedPill = app.buttons["server-status-pill"]
        XCTAssertTrue(disconnectedPill.waitForExistence(timeout: 5))
        XCTAssertEqual(disconnectedPill.label, "demo.local")
        XCTAssertTrue(app.buttons["library-filter-control"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Manual Movie"].waitForExistence(timeout: 5))

        refreshLibrary(in: app)

        XCTAssertFalse(app.staticTexts["Manual Movie"].waitForExistence(timeout: 2))
        XCTAssertTrue(disconnectedPill.waitForExistence(timeout: 5))
        XCTAssertEqual(disconnectedPill.label, "Disconnected")

        let reconnectButton = app.buttons["Open Connection Settings"]
        XCTAssertTrue(reconnectButton.waitForExistence(timeout: 5))

        reconnectButton.tap()

        XCTAssertTrue(app.staticTexts["Connection"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["setup-connect-button"].exists)
    }

    func test_connectedLaunchConnectionSheetAllowsDisconnectBackToConnectSheet() {
        let app = makeFixtureApp()

        let pillButton = app.buttons["server-status-pill"]
        XCTAssertTrue(pillButton.waitForExistence(timeout: 2))
        pillButton.tap()

        XCTAssertTrue(app.staticTexts["Connection"].waitForExistence(timeout: 2))
        let disconnectButton = app.buttons["Disconnect"]
        XCTAssertTrue(disconnectButton.waitForExistence(timeout: 2))

        disconnectButton.tap()

        XCTAssertTrue(app.staticTexts["Connect"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["setup-connect-button"].exists)
        XCTAssertFalse(app.buttons["Disconnect"].exists)
    }

    func test_addTabStartsTypeFirstAndHidesSearchUntilSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-library-fixture"]
        app.launch()

        openAddMedia(in: app)

        XCTAssertTrue(app.buttons["add-media-type-movie"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.textFields["add-media-search-field"].exists)
        XCTAssertFalse(app.buttons["add-media-provider-menu"].exists)
        XCTAssertFalse(app.staticTexts["Results"].exists)

        app.buttons["add-media-type-movie"].tap()

        XCTAssertTrue(app.textFields["add-media-search-field"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["add-media-provider-menu"].exists)
        XCTAssertFalse(app.staticTexts["Results"].exists)
        XCTAssertFalse(app.staticTexts["Search Movie"].exists)
        XCTAssertFalse(app.staticTexts["Results stay hidden until you run a search."].exists)
    }

    func test_addTabChoosingManualOpensManualEntrySheet() {
        let app = makeFixtureApp()

        openAddMedia(in: app)
        app.buttons["add-media-type-movie"].tap()
        app.buttons["add-media-provider-menu"].tap()
        let manualProviderButton = app.buttons["add-media-provider-manual"]
        XCTAssertTrue(manualProviderButton.waitForExistence(timeout: 2))
        manualProviderButton.tap()

        XCTAssertTrue(app.navigationBars["Manual Entry"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["add-media-manual-title-field"].waitForExistence(timeout: 2))
    }

    func test_addTabManualEntryCanCreateNewLibraryItem() {
        let app = makeFixtureApp()

        openAddMedia(in: app)
        app.buttons["add-media-type-movie"].tap()
        app.buttons["add-media-provider-menu"].tap()
        let manualProviderButton = app.buttons["add-media-provider-manual"]
        XCTAssertTrue(manualProviderButton.waitForExistence(timeout: 2))
        manualProviderButton.tap()

        let titleField = app.textFields["add-media-manual-title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Codex Manual Movie")

        let submitButton = app.buttons["add-media-manual-submit-button"]
        XCTAssertTrue(submitButton.isEnabled)
        submitButton.tap()

        XCTAssertFalse(app.navigationBars["Manual Entry"].waitForExistence(timeout: 2))
        assertLibraryShell(in: app)
        XCTAssertTrue(app.staticTexts["Codex Manual Movie"].waitForExistence(timeout: 5))
    }

    func test_addTabProviderSearchCanCreateResultAndReturnToLibrary() {
        let app = makeFixtureApp()

        openAddMedia(in: app)
        app.buttons["add-media-type-movie"].tap()

        let searchField = app.textFields["add-media-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("dune\n")

        let addButton = app.buttons["add-media-result-add-movie-tmdb-550"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let confirmationAlert = app.alerts.firstMatch
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: 2))
        confirmationAlert.buttons["Add"].tap()

        assertLibraryShell(in: app)
        XCTAssertTrue(app.staticTexts["Dune"].waitForExistence(timeout: 5))
    }

    func test_addTabProviderSearchShowsTrackedResultAsDisabled() {
        let app = makeFixtureApp(extraArguments: ["-ui-testing-tracked-search-result"])

        openAddMedia(in: app)
        app.buttons["add-media-type-movie"].tap()

        let searchField = app.textFields["add-media-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("dune\n")

        let addButton = app.buttons["add-media-result-add-movie-tmdb-550"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertFalse(addButton.isEnabled)
    }

    func test_addTabBookSearchCreatesNonNumericProviderItemWithoutOpeningDetail() {
        let app = makeFixtureApp()

        openAddMedia(in: app)
        app.buttons["add-media-type-book"].tap()

        let searchField = app.textFields["add-media-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("Glasperlenspiel\n")

        let addButton = app.buttons["add-media-result-add-book-openlibrary-OL27448W"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 2))
        app.alerts.firstMatch.buttons["Add"].tap()

        let bookTitle = app.staticTexts["Das Glasperlenspiel"]
        assertLibraryShell(in: app)
        XCTAssertTrue(bookTitle.waitForExistence(timeout: 5))

        app.otherElements["library-card-2"].tap()
        XCTAssertFalse(app.buttons["media-detail-primary-action-button"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Library"].exists)
    }

    func test_addTabSearchFailureShowsErrorMessage() {
        let app = makeFixtureApp(extraArguments: ["-ui-testing-search-error"])

        openAddMedia(in: app)
        app.buttons["add-media-type-movie"].tap()

        let searchField = app.textFields["add-media-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("dune\n")

        XCTAssertTrue(app.staticTexts["Search service offline"].waitForExistence(timeout: 5))
    }

    func test_bookBarcodeScanAddsFixtureBookToLibrary() {
        let isbn = "9780306406157"
        let app = makeFixtureApp(extraArguments: ["-ui-testing-simulated-book-isbn", isbn])

        openBookAddMedia(in: app)

        let addButton = app.buttons["add-media-result-add-book-openlibrary-OL27448W"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 2))
        app.alerts.firstMatch.buttons["Add"].tap()

        assertLibraryShell(in: app)
        XCTAssertTrue(app.staticTexts["Das Glasperlenspiel"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["library-card-2"].waitForExistence(timeout: 3))
    }

    func test_bookBarcodeNoMatchFallbackPrefillsISBNInSearchField() {
        let isbn = "9780140449136"
        let app = makeFixtureApp(extraArguments: ["-ui-testing-simulated-book-isbn", isbn])

        openBookAddMedia(in: app)

        XCTAssertTrue(app.staticTexts["No barcode match found."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["add-media-barcode-fallback-button"].waitForExistence(timeout: 2))
        app.buttons["add-media-barcode-fallback-button"].tap()

        let searchField = app.textFields["add-media-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        XCTAssertEqual(searchField.value as? String, isbn)
    }

    func test_libraryTrackingEditorCanSaveStatusChanges() {
        let app = makeFixtureApp()

        let statusSummary = app.buttons["library-card-status-button-1"]
        XCTAssertTrue(statusSummary.waitForExistence(timeout: 5))
        statusSummary.tap()

        let completedButton = app.buttons["media-detail-status-3-button"]
        XCTAssertTrue(completedButton.waitForExistence(timeout: 2))
        completedButton.tap()
        app.buttons["media-detail-save-button"].tap()

        XCTAssertFalse(app.buttons["media-detail-status-3-button"].waitForExistence(timeout: 2))
    }

    func test_libraryLoadErrorCanRetrySuccessfully() {
        let app = makeFixtureApp(extraArguments: ["-ui-testing-library-fails-once"])

        XCTAssertTrue(app.staticTexts["Library Error"].waitForExistence(timeout: 5))
        let retryButton = app.buttons["Try Again"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 2))

        retryButton.tap()

        XCTAssertTrue(app.buttons["library-filter-control"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["library-add-media-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Manual Movie"].waitForExistence(timeout: 5))
    }

    private func makeFixtureApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-library-fixture"]
        app.launch()
        return app
    }

    private func makeFixtureApp(extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-library-fixture"] + extraArguments
        app.launch()
        return app
    }

    private func makeDisconnectedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-invalid-auth"]
        app.launch()
        return app
    }

    private func makeExpiredAuthFixtureApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-library-auth-expired"]
        app.launch()
        return app
    }

    private func assertLibraryShell(in app: XCUIApplication, timeout: TimeInterval = 5) {
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["server-status-pill"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.buttons["library-add-media-button"].waitForExistence(timeout: timeout))
    }

    private func openAddMedia(in app: XCUIApplication) {
        let addButton = app.buttons["library-add-media-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        XCTAssertTrue(app.buttons["add-media-type-movie"].waitForExistence(timeout: 5))
    }

    private func openBookAddMedia(in app: XCUIApplication) {
        openAddMedia(in: app)
        XCTAssertTrue(app.buttons["add-media-type-book"].waitForExistence(timeout: 2))
        app.buttons["add-media-type-book"].tap()
    }

    private func replaceText(in element: XCUIElement, with text: String) {
        element.tap()

        guard let currentValue = element.value as? String else {
            element.typeText(text)
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        element.typeText(deleteString)
        element.typeText(text)
        XCTAssertEqual(element.value as? String, text)
    }

    private func refreshLibrary(in app: XCUIApplication) {
        let libraryScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(libraryScrollView.waitForExistence(timeout: 5))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
}

import XCTest

final class SetupFlowUITests: XCTestCase {
    func test_signedInLaunchShowsTabShell() {
        let app = makeFixtureApp()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 2))
        XCTAssertTrue(tabBar.buttons["Library"].exists)
        XCTAssertTrue(tabBar.buttons["Add"].exists)
        XCTAssertFalse(tabBar.buttons["Settings"].exists)
        XCTAssertTrue(app.buttons["server-status-pill"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.otherElements["library-control-bar"].waitForExistence(timeout: 2))
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

        XCTAssertTrue(app.staticTexts["Invalid token"].waitForExistence(timeout: 5))
    }

    func test_disconnectedLaunchShowsLibraryShellAndCanOpenConnectionSheet() {
        let app = makeDisconnectedApp()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Library"].exists)
        XCTAssertTrue(tabBar.buttons["Add"].exists)
        XCTAssertFalse(tabBar.buttons["Settings"].exists)
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        let disconnectedPill = app.buttons["server-status-pill"]
        XCTAssertTrue(disconnectedPill.waitForExistence(timeout: 5))
        XCTAssertEqual(disconnectedPill.label, "Disconnected")

        app.buttons["Open Connection Settings"].tap()

        XCTAssertTrue(app.navigationBars["Connection"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Connect"].exists)
    }

    func test_connectedLaunchConnectionSheetReconnectsAndUpdatesServerPill() {
        let app = makeFixtureApp()

        let pillButton = app.buttons["server-status-pill"]
        XCTAssertTrue(pillButton.waitForExistence(timeout: 2))
        XCTAssertEqual(pillButton.label, "demo.local")
        pillButton.tap()

        XCTAssertTrue(app.navigationBars["Connection"].waitForExistence(timeout: 2))

        let serverField = app.textFields["Server URL"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 2))
        replaceText(in: serverField, with: "https://second.local")

        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.isEnabled)
        connectButton.tap()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Connection"].exists)
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

        XCTAssertTrue(app.navigationBars["Connection"].waitForExistence(timeout: 2))

        let serverField = app.textFields["Server URL"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 2))
        replaceText(in: serverField, with: "not a url")

        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.isEnabled)
        connectButton.tap()

        XCTAssertTrue(app.staticTexts["Invalid server URL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Connection"].exists)

        app.buttons["Done"].tap()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        let unchangedPill = app.buttons["server-status-pill"]
        XCTAssertTrue(unchangedPill.waitForExistence(timeout: 5))
        XCTAssertEqual(unchangedPill.label, "demo.local")
    }

    func test_restoredSessionWithExpiredLibraryAuthShowsDisconnectedRecoveryPill() {
        let app = makeExpiredAuthFixtureApp()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.buttons["Library"].exists)
        XCTAssertTrue(tabBar.buttons["Add"].exists)
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))

        let disconnectedPill = app.buttons["server-status-pill"]
        XCTAssertTrue(disconnectedPill.waitForExistence(timeout: 5))
        XCTAssertEqual(disconnectedPill.label, "demo.local")
        XCTAssertTrue(app.otherElements["library-control-bar"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Manual Movie"].waitForExistence(timeout: 5))

        refreshLibrary(in: app)

        XCTAssertFalse(app.staticTexts["Manual Movie"].waitForExistence(timeout: 2))
        XCTAssertTrue(disconnectedPill.waitForExistence(timeout: 5))
        XCTAssertEqual(disconnectedPill.label, "Disconnected")

        let reconnectButton = app.buttons["Open Connection Settings"]
        XCTAssertTrue(reconnectButton.waitForExistence(timeout: 5))

        reconnectButton.tap()

        XCTAssertTrue(app.navigationBars["Connection"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Connect"].exists)
    }

    func test_connectedLaunchConnectionSheetAllowsDisconnectBackToConnectSheet() {
        let app = makeFixtureApp()

        let pillButton = app.buttons["server-status-pill"]
        XCTAssertTrue(pillButton.waitForExistence(timeout: 2))
        pillButton.tap()

        XCTAssertTrue(app.navigationBars["Connection"].waitForExistence(timeout: 2))
        let disconnectButton = app.buttons["Disconnect"]
        XCTAssertTrue(disconnectButton.waitForExistence(timeout: 2))

        disconnectButton.tap()

        XCTAssertTrue(app.navigationBars["Connect"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Connect"].exists)
        XCTAssertFalse(app.buttons["Disconnect"].exists)
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

    func test_libraryAddButtonRepeatedlyOpensAddMediaTab() {
        let app = makeFixtureApp()

        let addButton = app.buttons["library-add-media-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))

        for _ in 0..<5 {
            XCTAssertTrue(addButton.isHittable)
            addButton.tap()

            XCTAssertTrue(app.navigationBars["Add Media"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.textFields["add-media-search-field"].waitForExistence(timeout: 5))

            app.tabBars.firstMatch.buttons["Library"].tap()

            XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
            XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        }
    }

    func test_libraryAddButtonRemainsHittableWhileInitialLibraryLoadIsInProgress() {
        let app = makeFixtureApp(extraArguments: ["-ui-testing-library-delay-ms", "3000"])

        let loadingIndicator = app.activityIndicators.firstMatch
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 5))

        let addButton = app.buttons["library-add-media-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))
        XCTAssertTrue(addButton.isHittable)
    }

    func test_addTabManualEntryCanCreateNewLibraryItem() {
        let app = makeFixtureApp()

        app.tabBars.firstMatch.buttons["Add"].tap()
        app.buttons["add-media-source-manual"].tap()

        let titleField = app.textFields["add-media-manual-title-field"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("Codex Manual Movie")

        let submitButton = app.buttons["add-media-submit-button"]
        XCTAssertTrue(submitButton.isEnabled)
        submitButton.tap()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Codex Manual Movie"].waitForExistence(timeout: 5))
    }

    func test_addTabProviderSearchCanSelectAndCreateResult() {
        let app = makeFixtureApp()

        app.tabBars.firstMatch.buttons["Add"].tap()

        let searchField = app.textFields["add-media-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("dune\n")

        let resultButton = app.buttons["add-media-result-movie-tmdb-550"]
        XCTAssertTrue(resultButton.waitForExistence(timeout: 5))
        resultButton.tap()

        let submitButton = app.buttons["add-media-submit-button"]
        XCTAssertTrue(submitButton.isEnabled)
        submitButton.tap()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Dune"].waitForExistence(timeout: 5))
    }

    func test_addTabProviderSearchShowsTrackedResultAsDisabled() {
        let app = makeFixtureApp(extraArguments: ["-ui-testing-tracked-search-result"])

        app.tabBars.firstMatch.buttons["Add"].tap()

        let searchField = app.textFields["add-media-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("dune\n")

        let resultButton = app.buttons["add-media-result-movie-tmdb-550"]
        XCTAssertTrue(resultButton.waitForExistence(timeout: 5))
        XCTAssertFalse(resultButton.isEnabled)
        XCTAssertFalse(app.buttons["add-media-submit-button"].isEnabled)
    }

    func test_addTabBookSearchCreatesNonNumericProviderItemWithoutOpeningDetail() {
        let app = makeFixtureApp()

        app.tabBars.firstMatch.buttons["Add"].tap()
        app.buttons["add-media-type-book"].tap()
        app.buttons["add-media-source-openlibrary"].tap()

        let searchField = app.textFields["add-media-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("Glasperlenspiel\n")

        let resultButton = app.buttons["add-media-result-book-openlibrary-OL27448W"]
        XCTAssertTrue(resultButton.waitForExistence(timeout: 5))
        resultButton.tap()
        app.buttons["add-media-submit-button"].tap()

        let bookTitle = app.staticTexts["Das Glasperlenspiel"]
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(bookTitle.waitForExistence(timeout: 5))

        bookTitle.tap()
        XCTAssertFalse(app.buttons["media-detail-primary-action-button"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.navigationBars["Library"].exists)
    }

    func test_addTabSearchFailureShowsErrorMessage() {
        let app = makeFixtureApp(extraArguments: ["-ui-testing-search-error"])

        app.tabBars.firstMatch.buttons["Add"].tap()

        let searchField = app.textFields["add-media-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("dune\n")

        XCTAssertTrue(app.staticTexts["Search service offline"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["add-media-submit-button"].isEnabled)
    }

    func test_libraryDetailEditorCanSaveProgressChanges() {
        let app = makeFixtureApp()

        let libraryCardTitle = app.staticTexts["library-card-title-1"]
        XCTAssertTrue(libraryCardTitle.waitForExistence(timeout: 5))
        libraryCardTitle.tap()

        let actionButton = app.buttons["media-detail-primary-action-button"]
        XCTAssertTrue(actionButton.waitForExistence(timeout: 5))
        actionButton.tap()

        let progressField = app.textFields["media-detail-progress-field"]
        XCTAssertTrue(progressField.waitForExistence(timeout: 2))
        replaceText(in: progressField, with: "43")
        app.buttons["media-detail-save-button"].tap()

        XCTAssertFalse(app.textFields["media-detail-progress-field"].waitForExistence(timeout: 2))
    }

    func test_libraryLoadErrorCanRetrySuccessfully() {
        let app = makeFixtureApp(extraArguments: ["-ui-testing-library-fails-once"])

        XCTAssertTrue(app.staticTexts["Library Error"].waitForExistence(timeout: 5))
        let retryButton = app.buttons["Try Again"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 2))

        retryButton.tap()

        XCTAssertTrue(app.otherElements["library-control-bar"].waitForExistence(timeout: 5))
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

    private func replaceText(in element: XCUIElement, with text: String) {
        element.tap()

        guard let currentValue = element.value as? String else {
            element.typeText(text)
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        element.typeText(deleteString + text)
    }

    private func refreshLibrary(in app: XCUIApplication) {
        let libraryScrollView = app.scrollViews.firstMatch
        XCTAssertTrue(libraryScrollView.waitForExistence(timeout: 5))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.82))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
}

import XCTest

final class AppScreenshotUITests: XCTestCase {
    func test_captureAppScreenshots() throws {
        let outputDirectory = screenshotOutputDirectory.path
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-persisted-session", "-ui-testing-library-fixture"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
        saveScreenshot(named: "library", to: outputDirectory)

        app.tabBars.buttons["Add"].tap()
        let movieTypeButton = app.buttons["add-media-type-movie"]
        XCTAssertTrue(movieTypeButton.waitForExistence(timeout: 10))
        movieTypeButton.tap()
        XCTAssertTrue(app.textFields["add-media-search-field"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["add-media-provider-menu"].exists)
        saveScreenshot(named: "add-media", to: outputDirectory)

        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
        app.buttons["server-status-pill"].tap()
        XCTAssertTrue(app.navigationBars["Connection"].waitForExistence(timeout: 10))
        saveScreenshot(named: "settings", to: outputDirectory)
    }

    private func saveScreenshot(named name: String, to directory: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("Failed to write screenshot \(name): \(error)")
        }
    }

    private var screenshotOutputDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs")
            .appendingPathComponent("screenshots")
    }
}

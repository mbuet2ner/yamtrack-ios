import XCTest

@MainActor
final class AppScreenshotUITests: XCTestCase {
    private static let screenshotGenerationEnvironmentKey = "YAMTRACK_GENERATE_SCREENSHOTS"

    func test_captureAppScreenshots() throws {
        try XCTSkipUnless(
            Self.shouldGenerateScreenshots,
            "Set \(Self.screenshotGenerationEnvironmentKey)=1 to regenerate docs/screenshots."
        )

        let outputDirectory = screenshotOutputDirectory.path
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-persisted-session",
            "-ui-testing-library-fixture",
            "-ui-testing-screenshot-library"
        ]
        app.launchEnvironment[Self.screenshotGenerationEnvironmentKey] = "1"
        app.launchEnvironment["YAMTRACK_SCREENSHOT_LIBRARY"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Arrival"].waitForExistence(timeout: 10))
        waitForVisualSettling()
        saveScreenshot(named: "library", to: outputDirectory)

        let tIndexButton = app.buttons["library-index-T"]
        XCTAssertTrue(tIndexButton.waitForExistence(timeout: 5))
        tIndexButton.tap()
        XCTAssertTrue(app.staticTexts["Twin Peaks"].waitForExistence(timeout: 5))
        waitForVisualSettling()
        saveScreenshot(named: "library-t", to: outputDirectory)

        let trackingButton = app.buttons["library-card-status-button-3"]
        XCTAssertTrue(trackingButton.waitForExistence(timeout: 5))
        trackingButton.tap()
        XCTAssertTrue(app.staticTexts["Tracking"].waitForExistence(timeout: 5))
        waitForVisualSettling()
        saveScreenshot(named: "tracking", to: outputDirectory)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 5))

        app.buttons["library-add-media-button"].tap()
        let movieTypeButton = app.buttons["add-media-type-movie"]
        XCTAssertTrue(movieTypeButton.waitForExistence(timeout: 10))
        movieTypeButton.tap()
        XCTAssertTrue(app.textFields["add-media-search-field"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["add-media-provider-menu"].exists)
        waitForVisualSettling()
        saveScreenshot(named: "add-media", to: outputDirectory)

        app.buttons["Close"].tap()
        XCTAssertTrue(app.staticTexts["Library"].waitForExistence(timeout: 10))
        app.buttons["server-status-pill"].tap()
        XCTAssertTrue(app.staticTexts["Connection"].waitForExistence(timeout: 10))
        waitForVisualSettling()
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

    private func waitForVisualSettling() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }

    private static var shouldGenerateScreenshots: Bool {
        let value = ProcessInfo.processInfo.environment[screenshotGenerationEnvironmentKey]
        return value == "1"
    }

    private var screenshotOutputDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs")
            .appendingPathComponent("screenshots")
    }
}

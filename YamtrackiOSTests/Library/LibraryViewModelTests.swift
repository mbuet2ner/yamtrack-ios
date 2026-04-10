import XCTest
@testable import YamtrackiOS

@MainActor
final class LibraryViewModelTests: XCTestCase {
    func test_loadFetchesMediaAndAppliesFilter() async throws {
        let fixture = try loadFixtureData(named: "media-list")
        let spy = HTTPClientSpy(result: .success((
            fixture,
            HTTPURLResponse(
                url: URL(string: "https://demo.local/api/v1/media/")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )))
        let client = APIClient(httpClient: spy)
        let credentials = SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        let sut = LibraryViewModel(apiClient: client, credentials: credentials)

        await sut.load()

        XCTAssertEqual(sut.items.count, 2)
        XCTAssertEqual(sut.items.first?.title, "Dune")
        XCTAssertEqual(sut.items.first?.statusLabel, "Planning")
        XCTAssertEqual(sut.items.first?.progressLabel, "0")

        sut.selectedFilter = .movie

        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.title, "Dune")
    }

    func test_loadKeepsStateEmptyWhenServerReturnsNoResults() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"results":[]}"#.utf8),
            HTTPURLResponse(
                url: URL(string: "https://demo.local/api/v1/media/")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )))
        let client = APIClient(httpClient: spy)
        let credentials = SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        let sut = LibraryViewModel(apiClient: client, credentials: credentials)

        await sut.load()

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func test_loadSetsErrorMessageWhenServerRequestFails() async throws {
        let spy = HTTPClientSpy(result: .failure(URLError(.notConnectedToInternet)))
        let client = APIClient(httpClient: spy)
        let credentials = SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        let sut = LibraryViewModel(apiClient: client, credentials: credentials)

        await sut.load()

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertEqual(sut.errorMessage, "Server unreachable")
        XCTAssertFalse(sut.isLoading)
    }
}

private func loadFixtureData(named name: String) throws -> Data {
    let bundle = Bundle(for: LibraryViewModelTests.self)
    let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

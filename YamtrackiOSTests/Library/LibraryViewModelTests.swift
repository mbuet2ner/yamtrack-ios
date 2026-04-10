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
        sut.selectedFilter = .movie

        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.title, "Dune")
    }
}

private func loadFixtureData(named name: String) throws -> Data {
    let bundle = Bundle(for: LibraryViewModelTests.self)
    let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

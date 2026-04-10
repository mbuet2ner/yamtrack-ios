import XCTest
@testable import YamtrackiOS

@MainActor
final class MediaDetailViewModelTests: XCTestCase {
    func test_load_populatesActionFirstState() async throws {
        let spy = HTTPClientSpy(result: .success((
            try loadFixtureData(named: "media-detail-tv"),
            HTTPURLResponse(
                url: URL(string: "https://demo.local/api/v1/media/tv/tmdb/2/")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )))
        let sut = MediaDetailViewModel(
            mediaID: 2,
            source: "tmdb",
            mediaType: "tv",
            apiClient: APIClient(httpClient: spy),
            credentials: SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        )

        await sut.load()

        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/media/tv/tmdb/2/")
        XCTAssertEqual(sut.title, "Twin Peaks")
        XCTAssertEqual(sut.primaryActionTitle, "Mark Next Episode")
        XCTAssertEqual(sut.detail?.status, "In progress")
        XCTAssertEqual(sut.detail?.progress, 2)
        XCTAssertEqual(sut.detail?.totalCount, 8)
        XCTAssertEqual(sut.detail?.seasons?.count, 2)
    }
}

private func loadFixtureData(named name: String) throws -> Data {
    let bundle = Bundle(for: MediaDetailViewModelTests.self)
    let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

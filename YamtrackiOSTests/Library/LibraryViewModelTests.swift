import XCTest
@testable import YamtrackiOS

@MainActor
final class LibraryViewModelTests: XCTestCase {
    func test_loadFetchesMediaAndAppliesFilter() async throws {
        let spy = HTTPClientSpy(result: .success((
            try loadFixtureData(named: "media-list"),
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

    func test_loadFollowsPaginationUntilAllPagesAreLoaded() async throws {
        let firstPage = Data(#"{"pagination":{"total":2,"limit":1,"offset":0,"next":"https://demo.local/api/v1/media/?limit=1&offset=1","previous":null},"results":[{"id":101,"consumption_id":null,"item":{"media_id":1,"source":"manual","media_type":"movie","title":"Dune","image":"https://cdn.example.com/dune.jpg","season_number":null,"episode_number":null},"item_id":"movie/manual/1","parent_id":null,"tracked":true,"created_at":"2026-04-10T08:00:00Z","score":8.5,"status":0,"progress":0,"progressed_at":null,"start_date":null,"end_date":null,"notes":null,"lists":[]}]}"#.utf8)
        let secondPage = Data(#"{"pagination":{"total":2,"limit":1,"offset":1,"next":null,"previous":"https://demo.local/api/v1/media/?limit=1&offset=0"},"results":[{"id":102,"consumption_id":null,"item":{"media_id":2,"source":"manual","media_type":"tv","title":"Twin Peaks","image":"https://cdn.example.com/twin-peaks.jpg","season_number":null,"episode_number":null},"item_id":"tv/manual/2","parent_id":null,"tracked":true,"created_at":"2026-04-10T08:05:00Z","score":7.5,"status":1,"progress":2,"progressed_at":"2026-04-10T08:30:00Z","start_date":null,"end_date":null,"notes":null,"lists":[]}]}"#.utf8)

        let client = APIClient(httpClient: SequencedHTTPClientSpy(
            responses: [
                .success((
                    firstPage,
                    HTTPURLResponse(
                        url: URL(string: "https://demo.local/api/v1/media/")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )),
                .success((
                    secondPage,
                    HTTPURLResponse(
                        url: URL(string: "https://demo.local/api/v1/media/?limit=1&offset=1")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                ))
            ]
        ))
        let credentials = SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        let sut = LibraryViewModel(apiClient: client, credentials: credentials)

        await sut.load()

        XCTAssertEqual(sut.items.count, 2)
        XCTAssertEqual(sut.items.map(\.title), ["Dune", "Twin Peaks"])
    }

    func test_loadKeepsStateEmptyWhenServerReturnsNoResults() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"pagination":{"total":0,"limit":20,"offset":0,"next":null,"previous":null},"results":[]}"#.utf8),
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

    func test_loadMarksAuthenticationFailureWhenAPIRejectsToken() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"detail":"Invalid token"}"#.utf8),
            HTTPURLResponse(
                url: URL(string: "https://demo.local/api/v1/media/")!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            )!
        )))
        let client = APIClient(httpClient: spy)
        let credentials = SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        let sut = LibraryViewModel(apiClient: client, credentials: credentials)

        await sut.load()

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertEqual(sut.errorMessage, "Invalid token")
        XCTAssertTrue(sut.isAuthenticationError)
    }

    func test_makeDetailViewModel_returnsNilWhenNestedItemIsMissing() {
        let client = APIClient(httpClient: HTTPClientSpy(result: .failure(URLError(.notConnectedToInternet))))
        let credentials = SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        let sut = LibraryViewModel(apiClient: client, credentials: credentials)
        let summary = MediaSummary(
            databaseID: 42,
            consumptionID: nil,
            item: nil,
            itemID: nil,
            parentID: nil,
            tracked: true,
            createdAt: nil,
            score: nil,
            status: nil,
            progress: nil,
            progressedAt: nil,
            startDate: nil,
            endDate: nil,
            notes: nil,
            lists: []
        )

        XCTAssertNil(sut.makeDetailViewModel(for: summary))
    }

    func test_makeDetailViewModel_returnsViewModelWhenNestedItemExists() {
        let client = APIClient(httpClient: HTTPClientSpy(result: .failure(URLError(.notConnectedToInternet))))
        let credentials = SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        let sut = LibraryViewModel(apiClient: client, credentials: credentials)
        let summary = MediaSummary(
            databaseID: 42,
            consumptionID: nil,
            item: .init(
                mediaID: 2,
                source: "tmdb",
                mediaType: "tv",
                title: "Twin Peaks",
                image: nil,
                seasonNumber: nil,
                episodeNumber: nil
            ),
            itemID: nil,
            parentID: nil,
            tracked: true,
            createdAt: nil,
            score: nil,
            status: nil,
            progress: nil,
            progressedAt: nil,
            startDate: nil,
            endDate: nil,
            notes: nil,
            lists: []
        )

        XCTAssertNotNil(sut.makeDetailViewModel(for: summary))
    }
}

private func loadFixtureData(named name: String) throws -> Data {
    let bundle = Bundle(for: LibraryViewModelTests.self)
    let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private final class SequencedHTTPClientSpy: HTTPClient {
    private var responses: [Result<(Data, URLResponse), Error>]

    init(responses: [Result<(Data, URLResponse), Error>]) {
        self.responses = responses
    }

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard !responses.isEmpty else {
            XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
            throw URLError(.badServerResponse)
        }

        return try responses.removeFirst().get()
    }
}

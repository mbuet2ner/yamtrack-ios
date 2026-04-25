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
        XCTAssertNil(sut.items.first?.progressLabel)
        XCTAssertEqual(sut.items.first?.scoreLabel, "8.5 / 10")

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
        var didInvokeAuthenticationFailure = false
        sut.onAuthenticationFailure = {
            didInvokeAuthenticationFailure = true
        }

        await sut.load()

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertEqual(sut.errorMessage, "Invalid token")
        XCTAssertTrue(sut.isAuthenticationError)
        XCTAssertTrue(didInvokeAuthenticationFailure)
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
                mediaID: "2",
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

    func test_makeDetailViewModel_returnsNilForNonNumericProviderMediaID() {
        let client = APIClient(httpClient: HTTPClientSpy(result: .failure(URLError(.notConnectedToInternet))))
        let credentials = SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        let sut = LibraryViewModel(apiClient: client, credentials: credentials)
        let summary = MediaSummary(
            databaseID: 43,
            consumptionID: nil,
            item: .init(
                mediaID: "OL27448W",
                source: "openlibrary",
                mediaType: "book",
                title: "Das Glasperlenspiel",
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

        XCTAssertNil(sut.makeDetailViewModel(for: summary))
    }
}

final class MediaMetadataChipPresentationTests: XCTestCase {
    func test_makeChipsBuildsSemanticStatusAndScoreDescriptorsForMovies() {
        let item = MediaSummary(
            databaseID: 42,
            consumptionID: nil,
            item: .init(
                mediaID: "99",
                source: "tmdb",
                mediaType: "movie",
                title: "Arrival",
                image: nil,
                seasonNumber: nil,
                episodeNumber: nil
            ),
            itemID: nil,
            parentID: nil,
            tracked: true,
            createdAt: nil,
            score: 8.5,
            status: .completed,
            progress: 1,
            progressedAt: nil,
            startDate: nil,
            endDate: nil,
            notes: nil,
            lists: []
        )

        XCTAssertEqual(
            MediaMetadataChipPresentation.makeChips(for: item),
            [
                .init(text: "Completed", systemImage: "checkmark.circle.fill", tone: .positive, kind: .status),
                .init(text: "8.5 / 10", systemImage: "star.fill", tone: .rating, kind: .score)
            ]
        )
    }

    func test_makeChipsOmitsProgressChipWhenProgressIsMissing() {
        let item = MediaSummary(
            databaseID: 43,
            consumptionID: nil,
            item: .init(
                mediaID: "100",
                source: "tmdb",
                mediaType: "tv",
                title: "Severance",
                image: nil,
                seasonNumber: nil,
                episodeNumber: nil
            ),
            itemID: nil,
            parentID: nil,
            tracked: true,
            createdAt: nil,
            score: nil,
            status: .planning,
            progress: nil,
            progressedAt: nil,
            startDate: nil,
            endDate: nil,
            notes: nil,
            lists: []
        )

        XCTAssertEqual(
            MediaMetadataChipPresentation.makeChips(for: item),
            [
                .init(text: "Planning", systemImage: "clock.fill", tone: .neutral, kind: .status)
            ]
        )
    }
}

final class LibraryPresentationTests: XCTestCase {
    func test_groupsItemsByFirstLetterWithLocalizedTitleSortAndNumberBucketLast() {
        let presentation = LibraryPresentation(
            items: [
                makeMediaSummary(id: 1, title: "zebra"),
                makeMediaSummary(id: 2, title: "Alpha"),
                makeMediaSummary(id: 3, title: "10 Cloverfield Lane"),
                makeMediaSummary(id: 4, title: "Alien"),
                makeMediaSummary(id: 5, title: "Beta")
            ],
            allItems: [],
            selectedFilter: .all,
            searchText: ""
        )

        XCTAssertEqual(presentation.sections.map(\.title), ["A", "B", "Z", "#"])
        XCTAssertEqual(presentation.sections.map { $0.items.map(\.title) }, [
            ["Alien", "Alpha"],
            ["Beta"],
            ["zebra"],
            ["10 Cloverfield Lane"]
        ])
        XCTAssertEqual(presentation.indexLetters, ["A", "B", "Z", "#"])
    }

    func test_filtersSectionsByCaseInsensitiveQueryAfterTrimmingWhitespace() {
        let presentation = LibraryPresentation(
            items: [
                makeMediaSummary(id: 1, title: "Dune"),
                makeMediaSummary(id: 2, title: "Twin Peaks"),
                makeMediaSummary(id: 3, title: "Dune Messiah")
            ],
            allItems: [],
            selectedFilter: .all,
            searchText: "  dune  "
        )

        XCTAssertEqual(presentation.sections.map { $0.items.map(\.title) }, [
            ["Dune", "Dune Messiah"]
        ])
    }

    func test_metricsCountCompletedAndRatedVisibleItems() {
        let presentation = LibraryPresentation(
            items: [
                makeMediaSummary(id: 1, title: "Done Rated", score: 8, status: .completed),
                makeMediaSummary(id: 2, title: "Done Unrated", status: .completed),
                makeMediaSummary(id: 3, title: "Planning Rated", score: 7, status: .planning),
                makeMediaSummary(id: 4, title: "No Status")
            ],
            allItems: [],
            selectedFilter: .all,
            searchText: ""
        )

        XCTAssertEqual(presentation.completedCount, 2)
        XCTAssertEqual(presentation.ratedCount, 2)
    }
}

private func loadFixtureData(named name: String) throws -> Data {
    let bundle = Bundle(for: LibraryViewModelTests.self)
    let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private func makeMediaSummary(
    id: Int,
    title: String,
    mediaType: String = "movie",
    score: Double? = nil,
    status: MediaSummary.Status? = nil
) -> MediaSummary {
    MediaSummary(
        databaseID: id,
        consumptionID: nil,
        item: .init(
            mediaID: String(id),
            source: "manual",
            mediaType: mediaType,
            title: title,
            image: nil,
            seasonNumber: nil,
            episodeNumber: nil
        ),
        itemID: nil,
        parentID: nil,
        tracked: true,
        createdAt: nil,
        score: score,
        status: status,
        progress: nil,
        progressedAt: nil,
        startDate: nil,
        endDate: nil,
        notes: nil,
        lists: []
    )
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

import XCTest
@testable import YamtrackiOS

@MainActor
final class MediaDetailViewModelTests: XCTestCase {
    func test_trackingPresentation_clampsAndFormatsProgressByMediaType() {
        XCTAssertEqual(
            TrackingEditorPresentation.progressMaximum(mediaType: .tv, currentProgress: 30, totalCount: 24),
            30
        )
        XCTAssertEqual(
            TrackingEditorPresentation.progressMaximum(mediaType: .book, currentProgress: 12, totalCount: nil),
            100
        )
        XCTAssertEqual(
            TrackingEditorPresentation.clampedProgress(from: 14.6, maximum: 20),
            15
        )
        XCTAssertEqual(
            TrackingEditorPresentation.clampedProgress(from: -3, maximum: 20),
            0
        )
        XCTAssertEqual(
            TrackingEditorPresentation.progressDescription(mediaType: .anime, progress: 7),
            "7 episodes"
        )
    }

    func test_trackingPresentation_mapsBinaryProgressFromStatus() {
        XCTAssertEqual(
            TrackingEditorPresentation.savedProgress(
                mediaType: .movie,
                status: .completed,
                progress: 0
            ),
            1
        )
        XCTAssertEqual(
            TrackingEditorPresentation.savedProgress(
                mediaType: .movie,
                status: .inProgress,
                progress: 1
            ),
            0
        )
        XCTAssertEqual(
            TrackingEditorPresentation.progressAfterStatusChange(
                mediaType: .movie,
                status: .completed,
                currentProgress: 0
            ),
            1
        )
        XCTAssertEqual(
            TrackingEditorPresentation.progressAfterStatusChange(
                mediaType: .tv,
                status: .completed,
                currentProgress: 6
            ),
            6
        )
    }

    func test_trackingPresentation_formatsAndAdjustsScore() {
        XCTAssertEqual(TrackingEditorPresentation.scoreText(nil), "No score")
        XCTAssertEqual(TrackingEditorPresentation.scoreText(8), "8 / 10")
        XCTAssertEqual(TrackingEditorPresentation.scoreText(8.5), "8.5 / 10")
        XCTAssertEqual(TrackingEditorPresentation.scoreAfterAdjustment(nil, direction: .increment), 2)
        XCTAssertEqual(TrackingEditorPresentation.scoreAfterAdjustment(9, direction: .increment), 10)
        XCTAssertEqual(TrackingEditorPresentation.scoreAfterAdjustment(1, direction: .decrement), nil)
        XCTAssertEqual(TrackingEditorPresentation.scoreButtonAccessibilityValue(score: 6, buttonScore: 6), "Selected")
        XCTAssertEqual(TrackingEditorPresentation.scoreButtonAccessibilityValue(score: 6, buttonScore: 8), "Not selected")
    }

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

    func test_load_recoversAfterFailureOnRetry() async throws {
        let spy = SequencedHTTPClientSpy(
            responses: [
                .failure(URLError(.notConnectedToInternet)),
                .success((
                    try loadFixtureData(named: "media-detail-tv"),
                    HTTPURLResponse(
                        url: URL(string: "https://demo.local/api/v1/media/tv/tmdb/2/")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                ))
            ]
        )
        let sut = MediaDetailViewModel(
            mediaID: 2,
            source: "tmdb",
            mediaType: "tv",
            apiClient: APIClient(httpClient: spy),
            credentials: SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        )

        await sut.load()

        XCTAssertEqual(sut.errorMessage, "Server unreachable")
        XCTAssertNil(sut.detail)

        await sut.load()

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.title, "Twin Peaks")
    }

    func test_load_clearsStaleDetailAfterSubsequentFailure() async throws {
        let spy = SequencedHTTPClientSpy(
            responses: [
                .success((
                    try loadFixtureData(named: "media-detail-tv"),
                    HTTPURLResponse(
                        url: URL(string: "https://demo.local/api/v1/media/tv/tmdb/2/")!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )),
                .failure(URLError(.notConnectedToInternet))
            ]
        )
        let sut = MediaDetailViewModel(
            mediaID: 2,
            source: "tmdb",
            mediaType: "tv",
            apiClient: APIClient(httpClient: spy),
            credentials: SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        )

        await sut.load()
        XCTAssertEqual(sut.title, "Twin Peaks")

        await sut.load()

        XCTAssertEqual(sut.errorMessage, "Server unreachable")
        XCTAssertNil(sut.detail)
        XCTAssertEqual(sut.title, "")
    }

    func test_saveEdits_updatesManualMovieDetail() async throws {
        let initialDetail = Data(#"{"id":1,"media_id":1,"source":"manual","media_type":"movie","title":"Manual Movie","synopsis":null,"tracked":true,"details":{"status":"Planning"},"related":null,"item_id":"movie/manual/1","parent_id":null,"consumptions_number":1,"consumptions":[{"consumption_id":10,"created":"2026-04-11T08:00:00Z","score":null,"progress":0,"progressed_at":null,"status":0,"start_date":null,"end_date":null,"notes":null}],"lists":[]}"#.utf8)
        let updatedDetail = Data(#"{"id":1,"media_id":1,"source":"manual","media_type":"movie","title":"Manual Movie","synopsis":null,"tracked":true,"details":{"status":"Completed"},"related":null,"item_id":"movie/manual/1","parent_id":null,"consumptions_number":1,"consumptions":[{"consumption_id":10,"created":"2026-04-11T08:00:00Z","score":null,"progress":1,"progressed_at":null,"status":3,"start_date":null,"end_date":null,"notes":"Festival screening"}],"lists":[]}"#.utf8)
        let spy = SequencedHTTPClientSpy(
            responses: [
                .success((initialDetail, makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/media/movie/manual/1/")!))),
                .success((updatedDetail, makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/media/movie/manual/1/")!)))
            ]
        )
        let sut = MediaDetailViewModel(
            mediaID: 1,
            source: "manual",
            mediaType: "movie",
            apiClient: APIClient(httpClient: spy),
            credentials: SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        )

        await sut.load()
        try await sut.saveEdits(.init(status: .completed, progress: 1, score: nil, notes: "Festival screening"))

        XCTAssertEqual(sut.detail?.status, "Completed")
        XCTAssertEqual(sut.detail?.progress, 1)
        XCTAssertEqual(sut.detail?.trackingStatus, .completed)
        XCTAssertEqual(sut.detail?.notes, "Festival screening")
        XCTAssertNil(sut.saveErrorMessage)
    }

    func test_saveEdits_setsSaveErrorMessageOnFailure() async throws {
        let spy = SequencedHTTPClientSpy(
            responses: [
                .success((try loadFixtureData(named: "media-detail-tv"), makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/media/tv/tmdb/2/")!))),
                .failure(URLError(.notConnectedToInternet))
            ]
        )
        let sut = MediaDetailViewModel(
            mediaID: 2,
            source: "tmdb",
            mediaType: "tv",
            apiClient: APIClient(httpClient: spy),
            credentials: SessionCredentials(baseURL: URL(string: "https://demo.local")!, token: "secret")
        )

        await sut.load()

        do {
            try await sut.saveEdits(.init(status: .completed, progress: 8, score: nil, notes: nil))
            XCTFail("Expected save error")
        } catch {
            XCTAssertEqual(sut.saveErrorMessage, "Server unreachable")
            XCTAssertFalse(sut.isSaving)
            XCTAssertEqual(sut.detail?.progress, 2)
        }
    }
}

private func loadFixtureData(named name: String) throws -> Data {
    let bundle = Bundle(for: MediaDetailViewModelTests.self)
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

private func makeResponse(statusCode: Int, url: URL) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

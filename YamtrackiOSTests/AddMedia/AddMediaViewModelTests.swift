import XCTest
@testable import YamtrackiOS

@MainActor
final class AddMediaViewModelTests: XCTestCase {
    func test_searchLoadsProviderResultsForSelectedSource() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"pagination":{"total":1,"limit":20,"offset":0,"next":null,"previous":null},"results":[{"media_id":42,"source":"tmdb","media_type":"movie","title":"Dune","image":"https://cdn.example.com/dune.jpg","tracked":false,"item_id":null}]}"#.utf8),
            makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/movie/?search=dune&source=tmdb")!)
        )))
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        sut.selectedType = .movie
        sut.selectedSource = .tmdb
        sut.query = "dune"

        await sut.search()

        XCTAssertEqual(sut.results.map(\.title), ["Dune"])
        XCTAssertNil(sut.errorMessage)
    }

    func test_searchLoadsBookResultsWhenProviderReturnsStringMediaID() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"pagination":{"total":1,"limit":20,"offset":0,"next":null,"previous":null},"results":[{"media_id":"OL27448W","source":"openlibrary","media_type":"book","title":"Das Glasperlenspiel","image":"https://covers.openlibrary.org/b/id/1-L.jpg","tracked":false,"item_id":null}]}"#.utf8),
            makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=Glasperlenspiel&source=openlibrary")!)
        )))
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        sut.selectedType = .book
        sut.selectedSource = .openlibrary
        sut.query = "Glasperlenspiel"

        await sut.search()

        XCTAssertEqual(sut.results.map(\.title), ["Das Glasperlenspiel"])
        XCTAssertEqual(sut.results.first?.mediaID, "OL27448W")
        XCTAssertNil(sut.errorMessage)
    }

    func test_createManualMedia_notifiesOnSuccess() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"id":1,"consumption_id":null,"item":{"media_id":1,"source":"manual","media_type":"movie","title":"Manual Movie","image":null,"season_number":null,"episode_number":null},"item_id":"movie/manual/1","parent_id":null,"tracked":true,"created_at":"2026-04-11T08:00:00Z","score":null,"status":0,"progress":0,"progressed_at":null,"start_date":null,"end_date":null,"notes":null,"lists":[]}"#.utf8),
            makeResponse(statusCode: 201, url: URL(string: "https://demo.local/api/v1/media/movie/")!)
        )))
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        var createdMedia: MediaSummary?
        sut.onMediaCreated = { createdMedia = $0 }
        sut.selectedType = .movie
        sut.selectedSource = .manual
        sut.manualTitle = "Manual Movie"

        try await sut.createSelectedMedia()

        XCTAssertEqual(createdMedia?.title, "Manual Movie")
        XCTAssertFalse(sut.isCreating)
        XCTAssertNil(sut.errorMessage)
    }
}

private func makeCredentials() -> SessionCredentials {
    SessionCredentials(
        baseURL: URL(string: "https://demo.local")!,
        token: "secret"
    )
}

private func makeResponse(statusCode: Int, url: URL) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

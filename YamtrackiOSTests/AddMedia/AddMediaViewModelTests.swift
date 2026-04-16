import XCTest
@testable import YamtrackiOS

@MainActor
final class AddMediaViewModelTests: XCTestCase {
    func test_initStartsWithoutSelectedTypeOrSourceAndHasSearchedFalse() {
        let sut = makeSUT()

        XCTAssertNil(sut.selectedType)
        XCTAssertNil(sut.selectedSource)
        XCTAssertFalse(sut.hasSearched)
        XCTAssertFalse(sut.isShowingManualSheet)
        XCTAssertNil(sut.successMessage)
    }

    func test_selectTypeChoosesPreferredProviderAndPreservesQuery() {
        let sut = makeSUT()
        sut.query = "search term"
        sut.errorMessage = "Previous error"
        sut.successMessage = "Previous success"
        sut.hasSearched = true

        sut.selectType(.book)

        XCTAssertEqual(sut.selectedType, .book)
        XCTAssertEqual(sut.selectedSource, .openlibrary)
        XCTAssertEqual(sut.query, "search term")
        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertNil(sut.selectedResult)
        XCTAssertFalse(sut.hasSearched)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.successMessage)
    }

    func test_selectSourceClearsPriorResultsSelectionAndResetsHasSearched() throws {
        let sut = makeSUT()
        sut.selectType(.book)
        sut.results = [try makeSearchResult(
            mediaID: "OL27448W",
            source: "openlibrary",
            mediaType: "book",
            title: "Das Glasperlenspiel"
        )]
        sut.selectedResult = sut.results.first
        sut.errorMessage = "Previous error"
        sut.successMessage = "Previous success"
        sut.hasSearched = true

        sut.selectSource(.hardcover)

        XCTAssertEqual(sut.selectedSource, .hardcover)
        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertNil(sut.selectedResult)
        XCTAssertFalse(sut.hasSearched)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.successMessage)
    }

    func test_selectSourceManualKeepsCurrentSourceAndShowsManualSheet() {
        let sut = makeSUT()
        sut.selectType(.movie)
        let selectedSource = sut.selectedSource

        sut.selectSource(.manual)

        XCTAssertEqual(sut.selectedSource, selectedSource)
        XCTAssertTrue(sut.isShowingManualSheet)
    }

    func test_resetReturnsToNoSelectionState() {
        let sut = makeSUT()
        sut.selectType(.book)
        sut.selectSource(.hardcover)
        sut.query = "search term"
        sut.results = []
        sut.selectedResult = nil
        sut.hasSearched = true
        sut.isShowingManualSheet = true
        sut.errorMessage = "Oops"
        sut.successMessage = "Added Book"

        sut.reset()

        XCTAssertNil(sut.selectedType)
        XCTAssertNil(sut.selectedSource)
        XCTAssertEqual(sut.query, "")
        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertNil(sut.selectedResult)
        XCTAssertFalse(sut.hasSearched)
        XCTAssertFalse(sut.isShowingManualSheet)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.successMessage)
    }

    func test_searchWithEmptyQueryLeavesHasSearchedFalse() async {
        let sut = makeSUT()
        sut.selectType(.movie)
        sut.query = "   "

        await sut.search()

        XCTAssertFalse(sut.hasSearched)
        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertNil(sut.selectedResult)
    }

    func test_searchLoadsProviderResultsForSelectedSource() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"pagination":{"total":1,"limit":20,"offset":0,"next":null,"previous":null},"results":[{"media_id":42,"source":"tmdb","media_type":"movie","title":"Dune","image":"https://cdn.example.com/dune.jpg","tracked":false,"item_id":null}]}"#.utf8),
            makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/movie/?search=dune&source=tmdb")!)
        )))
        let sut = makeSUT(apiClient: APIClient(httpClient: spy))
        sut.selectType(.movie)
        sut.query = "dune"

        await sut.search()

        XCTAssertEqual(sut.results.map(\.title), ["Dune"])
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(sut.hasSearched)
    }

    func test_searchLoadsBookResultsWhenProviderReturnsStringMediaID() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"pagination":{"total":1,"limit":20,"offset":0,"next":null,"previous":null},"results":[{"media_id":"OL27448W","source":"openlibrary","media_type":"book","title":"Das Glasperlenspiel","image":"https://covers.openlibrary.org/b/id/1-L.jpg","tracked":false,"item_id":null}]}"#.utf8),
            makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=Glasperlenspiel&source=openlibrary")!)
        )))
        let sut = makeSUT(apiClient: APIClient(httpClient: spy))
        sut.selectType(.book)
        sut.query = "Glasperlenspiel"

        await sut.search()

        XCTAssertEqual(sut.results.map(\.title), ["Das Glasperlenspiel"])
        XCTAssertEqual(sut.results.first?.mediaID, "OL27448W")
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(sut.hasSearched)
    }

    func test_createManualMedia_notifiesOnSuccess() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"id":1,"consumption_id":null,"item":{"media_id":1,"source":"manual","media_type":"movie","title":"Manual Movie","image":null,"season_number":null,"episode_number":null},"item_id":"movie/manual/1","parent_id":null,"tracked":true,"created_at":"2026-04-11T08:00:00Z","score":null,"status":0,"progress":0,"progressed_at":null,"start_date":null,"end_date":null,"notes":null,"lists":[]}"#.utf8),
            makeResponse(statusCode: 201, url: URL(string: "https://demo.local/api/v1/media/movie/")!)
        )))
        let sut = makeSUT(apiClient: APIClient(httpClient: spy))
        var createdMedia: MediaSummary?
        sut.onMediaCreated = { createdMedia = $0 }
        sut.selectType(.movie)
        sut.selectSource(.manual)
        sut.manualTitle = "Manual Movie"

        try await sut.createSelectedMedia()

        XCTAssertEqual(createdMedia?.title, "Manual Movie")
        XCTAssertFalse(sut.isCreating)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.successMessage)
        XCTAssertEqual(spy.lastRequest?.httpMethod, "POST")
        XCTAssertTrue(String(data: spy.lastRequest?.httpBody ?? Data(), encoding: .utf8)?.contains(#""source":"manual""#) == true)
    }

    func test_createProviderMediaClearsSelectionAndStoresSuccessMessage() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"database_id":1,"consumption_id":null,"item":{"media_id":42,"source":"tmdb","media_type":"movie","title":"Dune","image":"https://cdn.example.com/dune.jpg","season_number":null,"episode_number":null},"item_id":"movie/tmdb/42","parent_id":null,"tracked":true,"created_at":"2026-04-11T08:00:00Z","score":null,"status":0,"progress":0,"progressed_at":null,"start_date":null,"end_date":null,"notes":null,"lists":[]}"#.utf8),
            makeResponse(statusCode: 201, url: URL(string: "https://demo.local/api/v1/media/movie/")!)
        )))
        let sut = makeSUT(apiClient: APIClient(httpClient: spy))
        var createdMedia: MediaSummary?
        sut.onMediaCreated = { createdMedia = $0 }
        sut.selectType(.movie)
        sut.selectedResult = try makeSearchResult(
            mediaID: "42",
            source: "tmdb",
            mediaType: "movie",
            title: "Dune"
        )

        try await sut.createSelectedMedia()

        XCTAssertEqual(createdMedia?.title, "Dune")
        XCTAssertNil(sut.selectedResult)
        XCTAssertEqual(sut.successMessage, "Added Dune")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isCreating)
    }
}

@MainActor
private func makeSUT(apiClient: APIClient = APIClient()) -> AddMediaViewModel {
    AddMediaViewModel(
        apiClient: apiClient,
        credentials: makeCredentials()
    )
}

private func makeCredentials() -> SessionCredentials {
    SessionCredentials(
        baseURL: URL(string: "https://demo.local")!,
        token: "secret"
    )
}

private func makeSearchResult(
    mediaID: String,
    source: String,
    mediaType: String,
    title: String
) throws -> AddMediaSearchResult {
    let data = Data(#"""
    {
      "media_id": "\#(mediaID)",
      "source": "\#(source)",
      "media_type": "\#(mediaType)",
      "title": "\#(title)",
      "image": null,
      "tracked": false,
      "item_id": null
    }
    """#.utf8)
    return try JSONDecoder().decode(AddMediaSearchResult.self, from: data)
}

private func makeResponse(statusCode: Int, url: URL) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

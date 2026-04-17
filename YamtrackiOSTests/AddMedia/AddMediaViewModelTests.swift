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
        sut.errorMessage = "Previous error"
        sut.successMessage = "Previous success"

        sut.selectSource(.manual)

        XCTAssertEqual(sut.selectedSource, selectedSource)
        XCTAssertTrue(sut.isShowingManualSheet)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.successMessage)
    }

    func test_dismissManualSheetHidesSheetWithoutChangingCurrentProviderSelection() {
        let sut = makeSUT()
        sut.selectType(.book)
        sut.selectSource(.hardcover)
        let selectedSource = sut.selectedSource
        sut.selectSource(.manual)
        sut.errorMessage = "Previous error"
        sut.successMessage = "Previous success"

        sut.dismissManualSheet()

        XCTAssertEqual(sut.selectedSource, selectedSource)
        XCTAssertFalse(sut.isShowingManualSheet)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.successMessage)
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

    func test_lookupBookBarcodeSearchesOpenLibraryFirstAndPreselectsSingleResult() async throws {
        let spy = BookBarcodeSequencedHTTPClientSpy(responses: [
            .success((
                Data(#"{"pagination":{"total":1,"limit":20,"offset":0,"next":null,"previous":null},"results":[{"media_id":"OL27448W","source":"openlibrary","media_type":"book","title":"Das Glasperlenspiel","image":"https://covers.openlibrary.org/b/id/1-L.jpg","tracked":false,"item_id":null}]}"#.utf8),
                makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=9780306406157&source=openlibrary")!)
            ))
        ])
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        sut.selectedType = .book

        await sut.lookupBookBarcode("978-0-306-40615-7")

        XCTAssertEqual(spy.requestedURLs, [
            "https://demo.local/api/v1/search/book/?search=9780306406157&source=openlibrary"
        ])
        XCTAssertEqual(sut.results.map(\.title), ["Das Glasperlenspiel"])
        XCTAssertEqual(sut.selectedResult?.mediaID, "OL27448W")
        XCTAssertEqual(sut.scannedISBN, "9780306406157")
        XCTAssertEqual(sut.barcodeLookupState, .results)
        XCTAssertNil(sut.errorMessage)
    }

    func test_lookupBookBarcodeFallsBackToHardcoverWhenOpenLibraryReturnsNoResults() async throws {
        let spy = BookBarcodeSequencedHTTPClientSpy(responses: [
            .success((
                Data(#"{"pagination":{"total":0,"limit":20,"offset":0,"next":null,"previous":null},"results":[]}"#.utf8),
                makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=9780306406157&source=openlibrary")!)
            )),
            .success((
                Data(#"{"pagination":{"total":1,"limit":20,"offset":0,"next":null,"previous":null},"results":[{"media_id":"123","source":"hardcover","media_type":"book","title":"Hardcover Match","image":null,"tracked":false,"item_id":null}]}"#.utf8),
                makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=9780306406157&source=hardcover")!)
            ))
        ])
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        sut.selectedType = .book

        await sut.lookupBookBarcode("9780306406157")

        XCTAssertEqual(spy.requestedURLs, [
            "https://demo.local/api/v1/search/book/?search=9780306406157&source=openlibrary",
            "https://demo.local/api/v1/search/book/?search=9780306406157&source=hardcover"
        ])
        XCTAssertEqual(sut.results.map(\.title), ["Hardcover Match"])
        XCTAssertEqual(sut.selectedResult?.mediaID, "123")
        XCTAssertEqual(sut.barcodeLookupState, .results)
        XCTAssertNil(sut.errorMessage)
    }

    func test_lookupBookBarcodeFallsBackToHardcoverWhenOpenLibraryFails() async throws {
        let spy = BookBarcodeSequencedHTTPClientSpy(responses: [
            .failure(URLError(.timedOut)),
            .success((
                Data(#"{"pagination":{"total":1,"limit":20,"offset":0,"next":null,"previous":null},"results":[{"media_id":"123","source":"hardcover","media_type":"book","title":"Hardcover Match","image":null,"tracked":false,"item_id":null}]}"#.utf8),
                makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=9780306406157&source=hardcover")!)
            ))
        ])
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        sut.selectedType = .book

        await sut.lookupBookBarcode("9780306406157")

        XCTAssertEqual(spy.requestedURLs, [
            "https://demo.local/api/v1/search/book/?search=9780306406157&source=openlibrary",
            "https://demo.local/api/v1/search/book/?search=9780306406157&source=hardcover"
        ])
        XCTAssertEqual(sut.results.map(\.title), ["Hardcover Match"])
        XCTAssertEqual(sut.selectedResult?.source, "hardcover")
        XCTAssertEqual(sut.barcodeLookupState, .results)
        XCTAssertNil(sut.errorMessage)
    }

    func test_lookupBookBarcodeExposesNoMatchStateWhenBothProvidersReturnNothing() async throws {
        let spy = BookBarcodeSequencedHTTPClientSpy(responses: [
            .success((
                Data(#"{"pagination":{"total":0,"limit":20,"offset":0,"next":null,"previous":null},"results":[]}"#.utf8),
                makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=9780306406157&source=openlibrary")!)
            )),
            .success((
                Data(#"{"pagination":{"total":0,"limit":20,"offset":0,"next":null,"previous":null},"results":[]}"#.utf8),
                makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=9780306406157&source=hardcover")!)
            ))
        ])
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        sut.selectedType = .book

        await sut.lookupBookBarcode("9780306406157")

        XCTAssertEqual(sut.results, [])
        XCTAssertNil(sut.selectedResult)
        XCTAssertEqual(sut.barcodeLookupState, .noMatch)
        XCTAssertNil(sut.errorMessage)
    }

    func test_moveScannedISBNToSearchFieldCopiesNormalizedISBNIntoQuery() async throws {
        let spy = BookBarcodeSequencedHTTPClientSpy(responses: [
            .success((
                Data(#"{"pagination":{"total":1,"limit":20,"offset":0,"next":null,"previous":null},"results":[{"media_id":"OL27448W","source":"openlibrary","media_type":"book","title":"Das Glasperlenspiel","image":null,"tracked":false,"item_id":null}]}"#.utf8),
                makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=9780306406157&source=openlibrary")!)
            ))
        ])
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        sut.selectedType = .book

        await sut.lookupBookBarcode("9780306406157")
        sut.moveScannedISBNToSearchField()

        XCTAssertEqual(sut.query, "9780306406157")
    }

    func test_moveScannedISBNToSearchFieldResetsBarcodeLookupState() async throws {
        let spy = BookBarcodeSequencedHTTPClientSpy(responses: [
            .success((
                Data(#"{"pagination":{"total":1,"limit":20,"offset":0,"next":null,"previous":null},"results":[{"media_id":"OL27448W","source":"openlibrary","media_type":"book","title":"Das Glasperlenspiel","image":null,"tracked":false,"item_id":null}]}"#.utf8),
                makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=9780306406157&source=openlibrary")!)
            ))
        ])
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        sut.selectedType = .book

        await sut.lookupBookBarcode("9780306406157")
        sut.moveScannedISBNToSearchField()

        XCTAssertEqual(sut.query, "9780306406157")
        XCTAssertNil(sut.scannedISBN)
        XCTAssertEqual(sut.results, [])
        XCTAssertNil(sut.selectedResult)
        XCTAssertEqual(sut.barcodeLookupState, .idle)
        XCTAssertNil(sut.errorMessage)
    }

    func test_lookupBookBarcodeRejectsInvalidISBN() async throws {
        let spy = BookBarcodeSequencedHTTPClientSpy(responses: [])
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        sut.selectedType = .book

        await sut.lookupBookBarcode("not-an-isbn")

        XCTAssertEqual(spy.requestedURLs, [])
        XCTAssertEqual(sut.results, [])
        XCTAssertNil(sut.selectedResult)
        XCTAssertEqual(sut.barcodeLookupState, .invalidISBN)
        XCTAssertEqual(sut.errorMessage, "That barcode does not look like a valid ISBN.")
    }

    func test_inFlightBarcodeLookup_isIgnoredAfterSelectedTypeChanges() async throws {
        let spy = ControllableBookBarcodeHTTPClientSpy()
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: spy),
            credentials: makeCredentials()
        )
        sut.selectedType = .book

        let lookupTask = Task { await sut.lookupBookBarcode("9780306406157") }
        await spy.waitUntilRequestIsStarted()

        sut.selectedType = .movie
        spy.resume(with: .success((
            Data(#"{"pagination":{"total":1,"limit":20,"offset":0,"next":null,"previous":null},"results":[{"media_id":"123","source":"openlibrary","media_type":"book","title":"Stale Result","image":null,"tracked":false,"item_id":null}]}"#.utf8),
            makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/book/?search=9780306406157&source=openlibrary")!)
        )))

        _ = await lookupTask.value

        XCTAssertEqual(sut.results, [])
        XCTAssertNil(sut.selectedResult)
        XCTAssertEqual(sut.barcodeLookupState, .idle)
    }

    func test_createSelectedMedia_usesSelectedResultProviderSourceAfterHardcoverFallback() async throws {
        let createSpy = HTTPClientSpy(result: .success((
            Data(#"{"id":12,"consumption_id":null,"item":{"media_id":"123","source":"hardcover","media_type":"book","title":"Hardcover Match","image":null,"season_number":null,"episode_number":null},"item_id":"book/hardcover/123","parent_id":null,"tracked":true,"created_at":"2026-04-11T08:00:00Z","score":null,"status":0,"progress":0,"progressed_at":null,"start_date":null,"end_date":null,"notes":null,"lists":[]}"#.utf8),
            makeResponse(statusCode: 201, url: URL(string: "https://demo.local/api/v1/media/book/")!)
        )))
        let sut = AddMediaViewModel(
            apiClient: APIClient(httpClient: createSpy),
            credentials: makeCredentials()
        )
        sut.selectedType = .book
        sut.selectedSource = .openlibrary
        sut.selectedResult = makeSearchResult(
            mediaID: "123",
            source: "hardcover",
            title: "Hardcover Match"
        )

        try await sut.createSelectedMedia()

        let body = try bodyDictionary(from: createSpy)
        XCTAssertEqual(body["source"] as? String, "hardcover")
        XCTAssertEqual(body["media_id"] as? String, "123")
        XCTAssertEqual(body["progress"] as? Int, 0)
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

    func test_createManualMedia_dismissesSheetStoresSuccessMessageAndNotifiesOnSuccess() async throws {
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

        try await sut.createManualMedia()

        XCTAssertEqual(createdMedia?.title, "Manual Movie")
        XCTAssertFalse(sut.isCreating)
        XCTAssertFalse(sut.isShowingManualSheet)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.successMessage, "Added Manual Movie")
        XCTAssertEqual(spy.lastRequest?.httpMethod, "POST")
        XCTAssertTrue(String(data: spy.lastRequest?.httpBody ?? Data(), encoding: .utf8)?.contains(#""source":"manual""#) == true)
    }

    func test_createSelectedMedia_withManualSourceSendsManualCreateRequest() async throws {
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
        XCTAssertEqual(spy.lastRequest?.httpMethod, "POST")
        XCTAssertTrue(String(data: spy.lastRequest?.httpBody ?? Data(), encoding: .utf8)?.contains(#""source":"manual""#) == true)
        XCTAssertNil(sut.successMessage)
        XCTAssertNil(sut.errorMessage)
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

    func test_createProviderMediaMarksCreatedResultTrackedInCurrentResults() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"database_id":1,"consumption_id":null,"item":{"media_id":42,"source":"tmdb","media_type":"movie","title":"Dune","image":"https://cdn.example.com/dune.jpg","season_number":null,"episode_number":null},"item_id":"movie/tmdb/42","parent_id":null,"tracked":true,"created_at":"2026-04-11T08:00:00Z","score":null,"status":0,"progress":0,"progressed_at":null,"start_date":null,"end_date":null,"notes":null,"lists":[]}"#.utf8),
            makeResponse(statusCode: 201, url: URL(string: "https://demo.local/api/v1/media/movie/")!)
        )))
        let sut = makeSUT(apiClient: APIClient(httpClient: spy))
        let result = try makeSearchResult(
            mediaID: "42",
            source: "tmdb",
            mediaType: "movie",
            title: "Dune"
        )
        sut.selectType(.movie)
        sut.results = [result]
        sut.selectedResult = result

        try await sut.createSelectedMedia()

        XCTAssertEqual(sut.results.count, 1)
        XCTAssertTrue(sut.results[0].tracked)
        XCTAssertEqual(sut.results[0].itemID, "movie/tmdb/42")
        XCTAssertNil(sut.selectedResult)
    }
}

@MainActor
private func makeSUT(apiClient: APIClient = APIClient()) -> AddMediaViewModel {
    AddMediaViewModel(
        apiClient: apiClient,
        credentials: makeCredentials()
    )
}

final class BookBarcodeSequencedHTTPClientSpy: HTTPClient {
    private var responses: [Result<(Data, URLResponse), Error>]
    private(set) var requestedURLs: [String] = []

    init(responses: [Result<(Data, URLResponse), Error>]) {
        self.responses = responses
    }

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requestedURLs.append(request.url?.absoluteString ?? "")
        guard !responses.isEmpty else {
            XCTFail("Unexpected extra HTTP request: \(request.url?.absoluteString ?? "nil")")
            throw URLError(.badServerResponse)
        }

        return try responses.removeFirst().get()
    }
}

@MainActor
final class ControllableBookBarcodeHTTPClientSpy: HTTPClient {
    private var pendingRequests: [CheckedContinuation<(Data, URLResponse), Error>] = []
    private(set) var requestedURLs: [String] = []

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requestedURLs.append(request.url?.absoluteString ?? "")
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests.append(continuation)
        }
    }

    func waitUntilRequestIsStarted() async {
        await waitUntilPendingRequestCount(atLeast: 1)
    }

    func waitUntilSecondRequestIsStarted() async {
        await waitUntilPendingRequestCount(atLeast: 2)
    }

    func resume(with result: Result<(Data, URLResponse), Error>) {
        guard let continuation = pendingRequests.first else {
            XCTFail("No pending request to resume")
            return
        }
        pendingRequests.removeFirst()
        continuation.resume(with: result)
    }

    func resumeNext(with result: Result<(Data, URLResponse), Error>) {
        resume(with: result)
    }

    private func waitUntilPendingRequestCount(atLeast count: Int) async {
        while pendingRequests.count < count {
            await Task.yield()
        }
    }
}

private func makeSearchResult(mediaID: String, source: String, title: String) -> AddMediaSearchResult {
    let data = Data(#"{"media_id":"\#(mediaID)","source":"\#(source)","media_type":"book","title":"\#(title)","image":null,"tracked":false,"item_id":null}"#.utf8)
    return try! JSONDecoder().decode(AddMediaSearchResult.self, from: data)
}

private func bodyDictionary(from spy: HTTPClientSpy) throws -> [String: Any] {
    let body = try XCTUnwrap(spy.lastRequest?.httpBody)
    let object = try JSONSerialization.jsonObject(with: body, options: [])
    return try XCTUnwrap(object as? [String: Any])
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

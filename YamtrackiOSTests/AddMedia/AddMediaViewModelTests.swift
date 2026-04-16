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

private func makeResponse(statusCode: Int, url: URL) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

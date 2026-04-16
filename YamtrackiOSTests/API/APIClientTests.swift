import XCTest
@testable import YamtrackiOS

final class APIClientTests: XCTestCase {
    func test_fetchInfo_sendsBearerTokenAndDecodesPayload() async throws {
        let spy = HTTPClientSpy(result: .success((try loadFixtureData(named: "info"), makeResponse(statusCode: 200))))
        let sut = makeSUT(httpClient: spy)
        let credentials = makeCredentials()

        let info = try await sut.fetchInfo(credentials: credentials)

        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/info/")
        XCTAssertEqual(spy.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(spy.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(info.version, "dev")
    }

    func test_fetchInfo_throwsUnauthorizedFor401() async throws {
        let spy = HTTPClientSpy(result: .success((Data(), makeResponse(statusCode: 401))))
        let sut = makeSUT(httpClient: spy)
        let credentials = makeCredentials()

        do {
            _ = try await sut.fetchInfo(credentials: credentials)
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func test_send_maps403InvalidTokenPayloadToUnauthorized() async throws {
        let spy = HTTPClientSpy(
            result: .success((
                Data(#"{"detail":"Invalid token"}"#.utf8),
                makeResponse(statusCode: 403, url: URL(string: "https://demo.local/api/v1/media/")!)
            ))
        )
        let sut = makeSUT(httpClient: spy)

        do {
            let _: PaginatedResponse<MediaSummary> = try await sut.send(Endpoint.mediaList(), credentials: makeCredentials())
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func test_fetchInfo_throwsServerErrorForNon401StatusCode() async throws {
        let spy = HTTPClientSpy(result: .success((Data("Internal Server Error".utf8), makeResponse(statusCode: 500))))
        let sut = makeSUT(httpClient: spy)

        do {
            _ = try await sut.fetchInfo(credentials: makeCredentials())
            XCTFail("Expected server error")
        } catch let error as APIError {
            XCTAssertEqual(error, .server("Internal Server Error"))
        }
    }

    func test_fetchInfo_throwsDecodingErrorForMalformedJSON() async throws {
        let spy = HTTPClientSpy(result: .success((Data("not json".utf8), makeResponse(statusCode: 200))))
        let sut = makeSUT(httpClient: spy)

        do {
            _ = try await sut.fetchInfo(credentials: makeCredentials())
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            XCTAssertEqual(error, .decoding)
        }
    }

    func test_fetchInfo_throwsTransportErrorForClientFailure() async throws {
        let spy = HTTPClientSpy(result: .failure(URLError(.notConnectedToInternet)))
        let sut = makeSUT(httpClient: spy)

        do {
            _ = try await sut.fetchInfo(credentials: makeCredentials())
            XCTFail("Expected transport error")
        } catch let error as APIError {
            XCTAssertEqual(error, .transport)
        }
    }

    func test_mediaList_decodesRealPaginatedNestedPayload() throws {
        let fixture = try loadFixtureData(named: "media-list")
        let response = try JSONDecoder().decode(PaginatedResponse<MediaSummary>.self, from: fixture)

        XCTAssertEqual(response.pagination.total, 2)
        XCTAssertEqual(response.pagination.limit, 20)
        XCTAssertEqual(response.results.count, 2)
        XCTAssertEqual(response.results.first?.title, "Dune")
        XCTAssertEqual(response.results.first?.item?.mediaType, "movie")
        XCTAssertEqual(response.results.first?.statusLabel, "Planning")
    }

    func test_fetchInfo_propagatesCancellation() async throws {
        let spy = HTTPClientSpy(result: .failure(CancellationError()))
        let sut = makeSUT(httpClient: spy)

        do {
            _ = try await sut.fetchInfo(credentials: makeCredentials())
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        }
    }

    func test_fetchInfo_buildsRequestUsingBaseURLPath() async throws {
        let spy = HTTPClientSpy(result: .success((try loadFixtureData(named: "info"), makeResponse(statusCode: 200, url: URL(string: "https://demo.local/tenant/api/v1/info/")!))))
        let sut = makeSUT(httpClient: spy)
        let credentials = SessionCredentials(baseURL: URL(string: "https://demo.local/tenant")!, token: "secret")

        _ = try await sut.fetchInfo(credentials: credentials)

        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/tenant/api/v1/info/")
    }

    func test_fixtureHTTPClient_decodesSeededMediaList() async throws {
        let sut = makeSUT(httpClient: UITestLibraryFixtureHTTPClient())

        let response: PaginatedResponse<MediaSummary> = try await sut.send(
            Endpoint.mediaList(),
            credentials: makeCredentials()
        )

        XCTAssertEqual(response.pagination.total, 1)
        XCTAssertEqual(response.results.count, 1)
        XCTAssertEqual(response.results.first?.title, "Manual Movie")
        XCTAssertEqual(response.results.first?.id, 1)
    }

    func test_fetchInfo_throwsInvalidURLForMalformedButParseableServerURLs() async throws {
        let sut = makeSUT()
        let invalidURLs = [
            "demo.local",
            "ftp://demo.local",
            "http://"
        ]

        for string in invalidURLs {
            guard let url = URL(string: string) else {
                XCTFail("Expected \(string) to be parseable enough for this regression test")
                continue
            }

            do {
                _ = try await sut.fetchInfo(credentials: SessionCredentials(baseURL: url, token: "secret"))
                XCTFail("Expected invalidURL for \(string)")
            } catch let error as APIError {
                XCTAssertEqual(error, .invalidURL, "Expected invalidURL for \(string)")
            }
        }
    }

    func test_searchMedia_buildsProviderSearchRequest() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"pagination":{"total":0,"limit":20,"offset":0,"next":null,"previous":null},"results":[]}"#.utf8),
            makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/search/movie/?search=dune&source=tmdb")!)
        )))
        let sut = makeSUT(httpClient: spy)

        let results = try await sut.searchMedia(
            query: "dune",
            mediaType: .movie,
            source: .tmdb,
            credentials: makeCredentials()
        )

        XCTAssertEqual(results, [])
        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/search/movie/?search=dune&source=tmdb")
        XCTAssertEqual(spy.lastRequest?.httpMethod, "GET")
    }

    func test_fixtureHTTPClient_returnsProviderSearchResults() async throws {
        let sut = makeSUT(httpClient: UITestLibraryFixtureHTTPClient())

        let results = try await sut.searchMedia(
            query: "dune",
            mediaType: .movie,
            source: .tmdb,
            credentials: makeCredentials()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Dune")
        XCTAssertEqual(results.first?.mediaID, "550")
        XCTAssertEqual(results.first?.source, "tmdb")
    }

    func test_createMedia_buildsManualCreateRequest() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"id":1,"consumption_id":null,"item":{"media_id":1,"source":"manual","media_type":"movie","title":"Manual Movie","image":null,"season_number":null,"episode_number":null},"item_id":"movie/manual/1","parent_id":null,"tracked":true,"created_at":"2026-04-11T08:00:00Z","score":null,"status":0,"progress":0,"progressed_at":null,"start_date":null,"end_date":null,"notes":null,"lists":[]}"#.utf8),
            makeResponse(statusCode: 201, url: URL(string: "https://demo.local/api/v1/media/movie/")!)
        )))
        let sut = makeSUT(httpClient: spy)

        let created = try await sut.createMedia(
            .manual(
                mediaType: .movie,
                title: "Manual Movie",
                imageURL: nil,
                status: nil,
                progress: nil,
                score: nil,
                notes: nil
            ),
            credentials: makeCredentials()
        )

        XCTAssertEqual(created.title, "Manual Movie")
        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/media/movie/")
        XCTAssertEqual(spy.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(try bodyDictionary(from: spy), ["source": "manual", "title": "Manual Movie"])
    }

    func test_updateMedia_buildsPatchRequestForManualMovie() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"id":1,"media_id":1,"source":"manual","media_type":"movie","title":"Manual Movie","synopsis":null,"tracked":true,"details":{"status":"Completed"},"related":null,"item_id":"movie/manual/1","parent_id":null,"consumptions_number":1,"consumptions":[{"consumption_id":10,"created":"2026-04-11T08:00:00Z","score":null,"progress":1,"progressed_at":null,"status":3,"start_date":null,"end_date":null,"notes":null}],"lists":[]}"#.utf8),
            makeResponse(statusCode: 200, url: URL(string: "https://demo.local/api/v1/media/movie/manual/1/")!)
        )))
        let sut = makeSUT(httpClient: spy)

        let updated = try await sut.updateMedia(
            mediaType: "movie",
            source: "manual",
            mediaID: "1",
            update: MediaUpdateRequest(status: .completed, progress: 1, score: nil, notes: nil),
            credentials: makeCredentials()
        )

        XCTAssertEqual(updated.title, "Manual Movie")
        XCTAssertEqual(updated.progress, 1)
        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/media/movie/manual/1/")
        XCTAssertEqual(spy.lastRequest?.httpMethod, "PATCH")
        XCTAssertEqual(try bodyDictionary(from: spy), ["status": 3, "progress": 1])
    }

    func test_createMedia_buildsProviderCreateRequestWithStringMediaID() async throws {
        let spy = HTTPClientSpy(result: .success((
            Data(#"{"id":12,"consumption_id":null,"item":{"media_id":"OL27448W","source":"openlibrary","media_type":"book","title":"Das Glasperlenspiel","image":null,"season_number":null,"episode_number":null},"item_id":"book/openlibrary/OL27448W","parent_id":null,"tracked":true,"created_at":"2026-04-11T08:00:00Z","score":null,"status":0,"progress":0,"progressed_at":null,"start_date":null,"end_date":null,"notes":null,"lists":[]}"#.utf8),
            makeResponse(statusCode: 201, url: URL(string: "https://demo.local/api/v1/media/book/")!)
        )))
        let sut = makeSUT(httpClient: spy)

        _ = try await sut.createMedia(
            .provider(
                mediaType: .book,
                source: .openlibrary,
                mediaID: "OL27448W",
                status: nil,
                progress: 0,
                score: nil,
                notes: nil
            ),
            credentials: makeCredentials()
        )

        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/media/book/")
        XCTAssertEqual(spy.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(try bodyDictionary(from: spy), ["source": "openlibrary", "media_id": "OL27448W", "progress": 0])
    }
}

private func loadFixtureData(named name: String) throws -> Data {
    let bundle = Bundle(for: APIClientTests.self)
    let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private func makeSUT(httpClient: HTTPClient = HTTPClientSpy(result: .success((Data(#"{"version":"dev"}"#.utf8), makeResponse(statusCode: 200))))) -> APIClient {
    APIClient(httpClient: httpClient)
}

private func makeCredentials() -> SessionCredentials {
    SessionCredentials(
        baseURL: URL(string: "https://demo.local")!,
        token: "secret"
    )
}

private func makeResponse(statusCode: Int, url: URL = URL(string: "https://demo.local/api/v1/info/")!) -> HTTPURLResponse {
    HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

private func bodyDictionary(from spy: HTTPClientSpy) throws -> [String: AnyHashable] {
    let body = try XCTUnwrap(spy.lastRequest?.httpBody)
    let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    return Dictionary(uniqueKeysWithValues: jsonObject.compactMap { key, value in
        if let string = value as? String {
            return (key, AnyHashable(string))
        }
        if let int = value as? Int {
            return (key, AnyHashable(int))
        }
        if let double = value as? Double {
            return (key, AnyHashable(double))
        }
        return nil
    })
}

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

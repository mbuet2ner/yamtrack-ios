import XCTest
@testable import YamtrackiOS

final class APIClientTests: XCTestCase {
    func test_fetchInfo_sendsBearerTokenAndDecodesPayload() async throws {
        let spy = HTTPClientSpy(result: .success((loadFixtureData(named: "info"), makeResponse(statusCode: 200))))
        let sut = makeSUT(httpClient: spy)
        let credentials = makeCredentials()

        let info = try await sut.fetchInfo(credentials: credentials)

        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/info/")
        XCTAssertEqual(spy.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(spy.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(info.name, "Yamtrack")
        XCTAssertEqual(info.version, "0.0.24")
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
        let spy = HTTPClientSpy(result: .success((loadFixtureData(named: "info"), makeResponse(statusCode: 200, url: URL(string: "https://demo.local/tenant/api/v1/info/")!))))
        let sut = makeSUT(httpClient: spy)
        let credentials = SessionCredentials(baseURL: URL(string: "https://demo.local/tenant")!, token: "secret")

        _ = try await sut.fetchInfo(credentials: credentials)

        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/tenant/api/v1/info/")
    }
}

private func loadFixtureData(named name: String) throws -> Data {
    let bundle = Bundle(for: APIClientTests.self)
    let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private func makeSUT(httpClient: HTTPClient = HTTPClientSpy(result: .success((Data(#"{"name":"Yamtrack","version":"0.0.24"}"#.utf8), makeResponse(statusCode: 200))))) -> APIClient {
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

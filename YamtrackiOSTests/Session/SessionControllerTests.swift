import XCTest
@testable import YamtrackiOS

@MainActor
final class SessionControllerTests: XCTestCase {
    func test_restoreCredentialsLoadsPersistedValues() async throws {
        let store = InMemorySessionStore()
        let credentials = SessionCredentials(
            baseURL: URL(string: "https://demo.local")!,
            token: "abc"
        )
        try store.save(try JSONEncoder().encode(credentials), for: SessionController.storageKey)

        let sut = makeSUT(store: store)

        await sut.restoreCredentials()

        XCTAssertEqual(sut.baseURLString, "https://demo.local")
        XCTAssertEqual(sut.token, "abc")
        XCTAssertTrue(sut.hasPersistedSession)
    }

    func test_connectRejectsInvalidURL() async throws {
        let store = InMemorySessionStore()
        let sut = makeSUT(store: store)
        sut.baseURLString = "not a url"
        sut.token = "secret"

        do {
            try await sut.connect()
            XCTFail("Expected invalidURL error")
        } catch let error as SessionError {
            XCTAssertEqual(error, .invalidURL)
        }

        XCTAssertNil(try store.loadValue(for: SessionController.storageKey))
        XCTAssertFalse(sut.hasPersistedSession)
    }

    func test_connectMapsTransportFailureToConnectionFailed() async throws {
        let store = InMemorySessionStore()
        let spy = HTTPClientSpy(result: .failure(URLError(.notConnectedToInternet)))
        let sut = makeSUT(store: store, httpClient: spy)
        sut.baseURLString = "https://demo.local"
        sut.token = "secret"

        do {
            try await sut.connect()
            XCTFail("Expected connectionFailed error")
        } catch let error as SessionError {
            XCTAssertEqual(error, .connectionFailed)
        }
    }

    func test_failedConnectDoesNotPersistCredentials() async throws {
        let store = InMemorySessionStore()
        let response = HTTPURLResponse(
            url: URL(string: "https://demo.local/api/v1/info/")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        let spy = HTTPClientSpy(result: .success((Data(), response)))
        let sut = makeSUT(store: store, httpClient: spy)
        sut.baseURLString = "https://demo.local"
        sut.token = "secret"

        do {
            try await sut.connect()
            XCTFail("Expected invalidToken error")
        } catch let error as SessionError {
            XCTAssertEqual(error, .invalidToken)
        }

        XCTAssertNil(try store.loadValue(for: SessionController.storageKey))
        XCTAssertFalse(sut.hasPersistedSession)
    }

    func test_connectUsesSharedAPIClientAndPersistsCredentials() async throws {
        let store = InMemorySessionStore()
        let response = HTTPURLResponse(
            url: URL(string: "https://demo.local/api/v1/info/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let spy = HTTPClientSpy(result: .success((Data(#"{"name":"Yamtrack","version":"0.0.24"}"#.utf8), response)))
        let sut = makeSUT(store: store, httpClient: spy)
        sut.baseURLString = "https://demo.local"
        sut.token = "secret"

        try await sut.connect()

        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/info/")
        XCTAssertEqual(spy.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(spy.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertTrue(sut.hasPersistedSession)

        let savedData = try XCTUnwrap(try store.loadValue(for: SessionController.storageKey))
        let saved = try JSONDecoder().decode(SessionCredentials.self, from: savedData)
        XCTAssertEqual(saved.baseURL.absoluteString, "https://demo.local")
        XCTAssertEqual(saved.token, "secret")
    }

    func test_logoutClearsPersistedCredentialsAndState() async throws {
        let store = InMemorySessionStore()
        let sut = makeSUT(store: store)
        sut.baseURLString = "https://demo.local"
        sut.token = "secret"

        try await sut.connect()
        sut.logout()

        XCTAssertEqual(sut.baseURLString, "")
        XCTAssertEqual(sut.token, "")
        XCTAssertFalse(sut.hasPersistedSession)
        XCTAssertNil(try store.loadValue(for: "session"))
    }

    private func makeSUT(
        store: InMemorySessionStore,
        httpClient: HTTPClient = HTTPClientSpy(
            result: .success((
                Data(#"{"name":"Yamtrack","version":"0.0.24"}"#.utf8),
                HTTPURLResponse(
                    url: URL(string: "https://demo.local/api/v1/info/")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ))
        )
    ) -> SessionController {
        SessionController(
            store: store,
            apiClient: APIClient(httpClient: httpClient)
        )
    }
}

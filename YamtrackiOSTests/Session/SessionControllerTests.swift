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
        XCTAssertEqual(sut.connectionStatus, .disconnected)
    }

    func test_restoreCredentialsClearsStaleValuesWhenNothingIsStored() async throws {
        let store = InMemorySessionStore()
        let sut = makeSUT(store: store)
        sut.baseURLString = "https://stale.local"
        sut.token = "stale-token"
        sut.hasPersistedSession = true
        sut.connectionStatus = .connected

        await sut.restoreCredentials()

        XCTAssertEqual(sut.baseURLString, "")
        XCTAssertEqual(sut.token, "")
        XCTAssertFalse(sut.hasPersistedSession)
        XCTAssertEqual(sut.connectionStatus, .disconnected)
    }

    func test_validatePersistedSessionMarksStatusConnectedWhenCredentialsWork() async throws {
        let store = InMemorySessionStore()
        let credentials = SessionCredentials(
            baseURL: URL(string: "https://demo.local")!,
            token: "secret"
        )
        try store.save(try JSONEncoder().encode(credentials), for: SessionController.storageKey)
        let sut = makeSUT(store: store)

        await sut.restoreCredentials()
        XCTAssertEqual(sut.connectionStatus, .disconnected)

        await sut.validatePersistedSession()

        XCTAssertEqual(sut.connectionStatus, .connected)
        XCTAssertEqual(sut.baseURLString, "https://demo.local")
        XCTAssertEqual(sut.token, "secret")
        XCTAssertTrue(sut.hasPersistedSession)
    }

    func test_validatePersistedSessionMarksStatusDisconnectedWhenTokenIsRejected() async throws {
        let store = InMemorySessionStore()
        let credentials = SessionCredentials(
            baseURL: URL(string: "https://demo.local")!,
            token: "secret"
        )
        try store.save(try JSONEncoder().encode(credentials), for: SessionController.storageKey)
        let response = HTTPURLResponse(
            url: URL(string: "https://demo.local/api/v1/info/")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        let sut = makeSUT(
            store: store,
            httpClient: HTTPClientSpy(result: .success((Data(), response)))
        )

        await sut.restoreCredentials()
        XCTAssertEqual(sut.connectionStatus, .disconnected)

        await sut.validatePersistedSession()

        XCTAssertEqual(sut.connectionStatus, .disconnected)
        XCTAssertEqual(sut.baseURLString, "https://demo.local")
        XCTAssertEqual(sut.token, "secret")
        XCTAssertTrue(sut.hasPersistedSession)
    }

    func test_markDisconnectedKeepsPersistedValuesForReconnectFlow() async throws {
        let store = InMemorySessionStore()
        let sut = makeSUT(store: store)
        sut.baseURLString = "https://demo.local"
        sut.token = "secret"

        try await sut.connect()
        XCTAssertEqual(sut.connectionStatus, .connected)

        sut.markDisconnected()

        XCTAssertEqual(sut.connectionStatus, .disconnected)
        XCTAssertEqual(sut.baseURLString, "https://demo.local")
        XCTAssertEqual(sut.token, "secret")
        XCTAssertTrue(sut.hasPersistedSession)
        let savedData = try XCTUnwrap(try store.loadValue(for: SessionController.storageKey))
        let saved = try JSONDecoder().decode(SessionCredentials.self, from: savedData)
        XCTAssertEqual(saved.baseURL.absoluteString, "https://demo.local")
        XCTAssertEqual(saved.token, "secret")
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

    func test_connectRejectsMalformedButParseableServerURLs() async throws {
        let store = InMemorySessionStore()
        let invalidURLs = [
            "demo.local",
            "ftp://demo.local",
            "http://"
        ]

        for string in invalidURLs {
            let sut = makeSUT(store: store)
            sut.baseURLString = string
            sut.token = "secret"

            do {
                try await sut.connect()
                XCTFail("Expected invalidURL error for \(string)")
            } catch let error as SessionError {
                XCTAssertEqual(error, .invalidURL, "Expected invalidURL error for \(string)")
            }
        }
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

    func test_connectAllowsEphemeralSessionWhenCredentialsCannotBeSaved() async throws {
        let store = FailingSessionStore(
            saveError: NSError(domain: NSOSStatusErrorDomain, code: -34018)
        )
        let sut = SessionController(
            store: store,
            apiClient: APIClient(
                httpClient: HTTPClientSpy(
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
            )
        )
        sut.baseURLString = "https://demo.local"
        sut.token = "secret"

        try await sut.connect()

        XCTAssertFalse(sut.hasPersistedSession)
        XCTAssertEqual(sut.connectionStatus, .connected)
        XCTAssertEqual(
            sut.sessionWarningMessage,
            "Connected for now, but couldn't save your connection securely on this device."
        )
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
        XCTAssertEqual(sut.connectionStatus, .connected)

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
        XCTAssertEqual(sut.connectionStatus, .disconnected)
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

private struct FailingSessionStore: SessionStoring {
    let saveError: Error

    func save(_ data: Data, for key: String) throws {
        throw saveError
    }

    func loadValue(for key: String) throws -> Data? {
        nil
    }

    func deleteValue(for key: String) {}
}

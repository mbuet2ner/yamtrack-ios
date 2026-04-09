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

        let sut = SessionController(store: store, validator: SessionInfoValidatorSpy())

        await sut.restoreCredentials()

        XCTAssertEqual(sut.baseURLString, "https://demo.local")
        XCTAssertEqual(sut.token, "abc")
        XCTAssertTrue(sut.hasPersistedSession)
    }

    func test_connectRejectsInvalidURL() async throws {
        let store = InMemorySessionStore()
        let sut = SessionController(store: store, validator: SessionInfoValidatorSpy())
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

    func test_connectPropagatesValidatorFailure() async throws {
        let store = InMemorySessionStore()
        let validator = SessionInfoValidatorSpy(error: SessionError.connectionFailed)
        let sut = SessionController(store: store, validator: validator)
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
        let validator = SessionInfoValidatorSpy(error: SessionError.invalidToken)
        let sut = SessionController(store: store, validator: validator)
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

    func test_connectValidatesInfoEndpointAndPersistsCredentials() async throws {
        let store = InMemorySessionStore()
        let validator = SessionInfoValidatorSpy()
        let sut = SessionController(store: store, validator: validator)
        sut.baseURLString = "https://demo.local"
        sut.token = "secret"

        try await sut.connect()

        XCTAssertEqual(validator.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/info/")
        XCTAssertEqual(validator.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertTrue(sut.hasPersistedSession)

        let savedData = try XCTUnwrap(try store.loadValue(for: SessionController.storageKey))
        let saved = try JSONDecoder().decode(SessionCredentials.self, from: savedData)
        XCTAssertEqual(saved.baseURL.absoluteString, "https://demo.local")
        XCTAssertEqual(saved.token, "secret")
    }

    func test_logoutClearsPersistedCredentialsAndState() async throws {
        let store = InMemorySessionStore()
        let sut = SessionController(store: store, validator: SessionInfoValidatorSpy())
        sut.baseURLString = "https://demo.local"
        sut.token = "secret"

        try await sut.connect()
        sut.logout()

        XCTAssertEqual(sut.baseURLString, "")
        XCTAssertEqual(sut.token, "")
        XCTAssertFalse(sut.hasPersistedSession)
        XCTAssertNil(try store.loadValue(for: "session"))
    }
}

private final class SessionInfoValidatorSpy: SessionInfoValidating, @unchecked Sendable {
    private(set) var lastRequest: URLRequest?
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func validate(_ request: URLRequest) async throws {
        lastRequest = request
        if let error {
            throw error
        }
    }
}

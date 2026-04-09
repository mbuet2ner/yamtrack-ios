import XCTest
@testable import YamtrackiOS

@MainActor
final class SessionControllerTests: XCTestCase {
    func test_restoreCredentialsLoadsPersistedValues() async throws {
        let store = KeychainStore(service: "test.\(UUID().uuidString)", accessGroup: nil)
        let credentials = SessionCredentials(
            baseURL: URL(string: "https://demo.local")!,
            token: "abc"
        )
        let data = try JSONEncoder().encode(credentials)
        try store.save(data, for: "session")

        let sut = SessionController(store: store, validator: SessionInfoValidatorSpy())

        await sut.restoreCredentials()

        XCTAssertEqual(sut.baseURLString, "https://demo.local")
        XCTAssertEqual(sut.token, "abc")
        XCTAssertTrue(sut.hasPersistedSession)
    }

    func test_connectValidatesInfoEndpointAndPersistsCredentials() async throws {
        let store = KeychainStore(service: "test.\(UUID().uuidString)", accessGroup: nil)
        let validator = SessionInfoValidatorSpy()
        let sut = SessionController(store: store, validator: validator)
        sut.baseURLString = "https://demo.local"
        sut.token = "secret"

        try await sut.connect()

        XCTAssertEqual(validator.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/info/")
        XCTAssertEqual(validator.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertTrue(sut.hasPersistedSession)

        let savedData = try XCTUnwrap(try store.loadValue(for: "session"))
        let saved = try JSONDecoder().decode(SessionCredentials.self, from: savedData)
        XCTAssertEqual(saved.baseURL.absoluteString, "https://demo.local")
        XCTAssertEqual(saved.token, "secret")
    }

    func test_logoutClearsPersistedCredentialsAndState() async throws {
        let store = KeychainStore(service: "test.\(UUID().uuidString)", accessGroup: nil)
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

    func validate(_ request: URLRequest) async throws {
        lastRequest = request
    }
}

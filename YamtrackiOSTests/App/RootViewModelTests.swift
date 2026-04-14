import XCTest
@testable import YamtrackiOS

@MainActor
final class RootViewModelTests: XCTestCase {
    func test_restoreSessionInitializesLibraryViewModelFromPersistedCredentials() async throws {
        let store = InMemorySessionStore()
        let credentials = SessionCredentials(
            baseURL: URL(string: "https://demo.local")!,
            token: "secret"
        )
        try store.save(try JSONEncoder().encode(credentials), for: SessionController.storageKey)
        let session = SessionController(store: store, apiClient: makeInfoClient())
        let injectedClient = APIClient(httpClient: HTTPClientSpy(result: .failure(URLError(.notConnectedToInternet))))
        let sut = RootViewModel(apiClient: injectedClient)

        await sut.restoreSession(using: session)

        XCTAssertFalse(sut.isRestoringSession)
        XCTAssertNotNil(sut.libraryViewModel)
    }

    func test_restoreSessionValidatesPersistedCredentialsBeforeCreatingLibraryViewModel() async throws {
        let store = InMemorySessionStore()
        let credentials = SessionCredentials(
            baseURL: URL(string: "https://demo.local")!,
            token: "secret"
        )
        try store.save(try JSONEncoder().encode(credentials), for: SessionController.storageKey)
        let session = SessionController(store: store, apiClient: makeInfoClient())
        let sut = RootViewModel(apiClient: makeInfoClient())

        await sut.restoreSession(using: session)

        XCTAssertEqual(session.connectionStatus, .connected)
        XCTAssertNotNil(sut.libraryViewModel)
    }

    func test_restoreSessionLeavesLibraryViewModelNilWhenPersistedCredentialsAreRejected() async throws {
        let store = InMemorySessionStore()
        let credentials = SessionCredentials(
            baseURL: URL(string: "https://demo.local")!,
            token: "secret"
        )
        try store.save(try JSONEncoder().encode(credentials), for: SessionController.storageKey)
        let session = SessionController(store: store, apiClient: makeUnauthorizedInfoClient())
        let sut = RootViewModel(apiClient: makeInfoClient())

        await sut.restoreSession(using: session)

        XCTAssertEqual(session.connectionStatus, .disconnected)
        XCTAssertNil(sut.libraryViewModel)
    }

    func test_sessionDidChangeInitializesLibraryViewModelAfterSuccessfulConnect() async throws {
        let store = InMemorySessionStore()
        let client = makeInfoClient()
        let session = SessionController(store: store, apiClient: client)
        session.baseURLString = "https://demo.local"
        session.token = "secret"
        let sut = RootViewModel(apiClient: client)

        try await session.connect()
        sut.sessionDidChange(using: session)

        XCTAssertNotNil(sut.libraryViewModel)
    }

    func test_sessionDidChangeClearsLibraryViewModelAfterLogout() async throws {
        let store = InMemorySessionStore()
        let session = SessionController(store: store, apiClient: makeInfoClient())
        session.baseURLString = "https://demo.local"
        session.token = "secret"
        let sut = RootViewModel(apiClient: makeInfoClient())

        try await session.connect()
        sut.sessionDidChange(using: session)
        XCTAssertNotNil(sut.libraryViewModel)

        session.logout()
        sut.sessionDidChange(using: session)

        XCTAssertNil(sut.libraryViewModel)
    }

    private func makeInfoClient() -> APIClient {
        let response = HTTPURLResponse(
            url: URL(string: "https://demo.local/api/v1/info/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return APIClient(
            httpClient: HTTPClientSpy(
                result: .success((Data(#"{"version":"0.0.24"}"#.utf8), response))
            )
        )
    }

    private func makeUnauthorizedInfoClient() -> APIClient {
        let response = HTTPURLResponse(
            url: URL(string: "https://demo.local/api/v1/info/")!,
            statusCode: 403,
            httpVersion: nil,
            headerFields: nil
        )!
        return APIClient(
            httpClient: HTTPClientSpy(
                result: .success((Data(#"{"detail":"Invalid token"}"#.utf8), response))
            )
        )
    }
}

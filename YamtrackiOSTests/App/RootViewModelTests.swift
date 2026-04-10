import XCTest
@testable import YamtrackiOS

@MainActor
final class RootViewModelTests: XCTestCase {
    func test_sessionDidChangeInitializesLibraryViewModelAfterSuccessfulConnect() async throws {
        let store = InMemorySessionStore()
        let response = HTTPURLResponse(
            url: URL(string: "https://demo.local/api/v1/info/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let client = APIClient(httpClient: HTTPClientSpy(result: .success((Data(#"{"name":"Yamtrack","version":"0.0.24"}"#.utf8), response))))
        let session = SessionController(store: store, apiClient: client)
        session.baseURLString = "https://demo.local"
        session.token = "secret"
        let sut = RootViewModel()

        try await session.connect()
        sut.sessionDidChange(using: session)

        XCTAssertNotNil(sut.libraryViewModel)
    }
}

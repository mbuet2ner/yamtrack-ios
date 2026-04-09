import Foundation
import SwiftUI

@main
struct YamtrackiOSApp: App {
    private let rootView: RootView

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let invalidAuth = arguments.contains("-ui-testing-invalid-auth")
        let shouldUseTestStore = arguments.contains("-ui-testing-persisted-session") || arguments.contains("-ui-testing-invalid-auth") || arguments.contains("-ui-testing-reset-session")
        let store: SessionStoring = shouldUseTestStore ? InMemorySessionStore() : KeychainStore(service: "org.yamtrack.ios.session", accessGroup: nil)

        if arguments.contains("-ui-testing-persisted-session"),
           let testStore = store as? InMemorySessionStore {
            let credentials = SessionCredentials(
                baseURL: URL(string: "https://demo.local")!,
                token: "test-token"
            )
            try? testStore.save(try! JSONEncoder().encode(credentials), for: SessionController.storageKey)
        }

        let apiClient = invalidAuth
            ? APIClient(httpClient: UIInvalidAuthHTTPClient())
            : APIClient.live

        let session = SessionController.live(
            store: store,
            apiClient: apiClient
        )

        if arguments.contains("-ui-testing-reset-session") {
            session.logout()
        }

        rootView = RootView(session: session)
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }
}

private struct UIInvalidAuthHTTPClient: HTTPClient {
    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://demo.local/api/v1/info/")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }
}

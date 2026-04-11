import Foundation
import SwiftUI

@main
struct YamtrackiOSApp: App {
    private let rootView: RootView

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let invalidAuth = arguments.contains("-ui-testing-invalid-auth")
        let useLibraryFixture = arguments.contains("-ui-testing-library-fixture")
        let shouldUseTestStore = arguments.contains("-ui-testing-persisted-session") || arguments.contains("-ui-testing-invalid-auth") || arguments.contains("-ui-testing-reset-session")
        let store: SessionStoring = shouldUseTestStore ? InMemorySessionStore() : KeychainStore(service: "com.maltepaulbuttner.yamtrackios.session", accessGroup: nil)

        if arguments.contains("-ui-testing-persisted-session"),
           let testStore = store as? InMemorySessionStore {
            let credentials = SessionCredentials(
                baseURL: URL(string: "https://demo.local")!,
                token: "test-token"
            )
            try? testStore.save(try! JSONEncoder().encode(credentials), for: SessionController.storageKey)
        }

        let apiClient: APIClient
        if invalidAuth {
            apiClient = APIClient(httpClient: UIInvalidAuthHTTPClient())
        } else if useLibraryFixture {
            apiClient = APIClient(httpClient: UITestLibraryFixtureHTTPClient())
        } else {
            apiClient = APIClient.live
        }

        let session = SessionController.live(
            store: store,
            apiClient: apiClient
        )

        if arguments.contains("-ui-testing-reset-session") {
            session.logout()
        }

        rootView = RootView(session: session, apiClient: apiClient)
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }
}

struct UIInvalidAuthHTTPClient: HTTPClient {
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

struct UITestLibraryFixtureHTTPClient: HTTPClient {
    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        switch normalizedPath(for: url) {
        case "/api/v1/info":
            return (Data(#"{"version":"dev"}"#.utf8), response)
        case "/api/v1/media":
            return (Data(Self.mediaList.utf8), response)
        case "/api/v1/media/movie/manual/1":
            return (Data(Self.mediaDetail.utf8), response)
        default:
            let notFound = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(#"{"detail":"Not found"}"#.utf8), notFound)
        }
    }

    private func normalizedPath(for url: URL) -> String {
        var path = url.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private static let mediaList = #"""
    {
      "pagination": {
        "total": 1,
        "limit": 20,
        "offset": 0,
        "next": null,
        "previous": null
      },
      "results": [
        {
          "id": 1,
          "consumption_id": null,
          "item": {
            "media_id": 1,
            "source": "manual",
            "media_type": "movie",
            "title": "Manual Movie",
            "image": null,
            "season_number": null,
            "episode_number": null
          },
          "item_id": "movie/manual/1",
          "parent_id": null,
          "tracked": true,
          "created_at": "2026-04-11T10:00:00Z",
          "score": null,
          "status": 1,
          "progress": 42,
          "progressed_at": "2026-04-11T10:30:00Z",
          "start_date": null,
          "end_date": null,
          "notes": null,
          "lists": []
        }
      ]
    }
    """#

    private static let mediaDetail = #"""
    {
      "media_id": 1,
      "source": "manual",
      "media_type": "movie",
      "title": "Manual Movie",
      "synopsis": "Fixture-backed movie detail for UI testing.",
      "tracked": true,
      "details": {
        "status": "In progress"
      },
      "consumptions": [
        {
          "progress": 42
        }
      ]
    }
    """#
}

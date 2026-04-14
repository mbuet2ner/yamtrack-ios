import Foundation
import SwiftUI

@main
struct YamtrackiOSApp: App {
    private let rootView: RootView

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let invalidAuth = arguments.contains("-ui-testing-invalid-auth")
        let useLibraryFixture = arguments.contains("-ui-testing-library-fixture")
        let simulatedBookISBN = ProcessInfo.processInfo.value(after: "-ui-testing-simulated-book-isbn")
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
            apiClient = APIClient(httpClient: UITestLibraryFixtureHTTPClient(simulatedBookISBN: simulatedBookISBN))
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

actor UITestLibraryFixtureHTTPClient: HTTPClient {
    private static let matchedFixtureBookISBN = "9780306406157"

    private let simulatedBookISBN: String?
    private var libraryItems: [FixtureLibraryItem] = [.seededManualMovie]
    private var nextLibraryID = 2

    init(simulatedBookISBN: String? = nil) {
        self.simulatedBookISBN = simulatedBookISBN
    }

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
            return (try listResponse(), response)
        case "/api/v1/media/movie/manual/1":
            return (Data(Self.mediaDetail.utf8), response)
        case "/api/v1/search/book":
            return (try bookSearchResponse(for: url), response)
        case "/api/v1/media/book":
            if request.httpMethod == "POST" {
                return try createBookResponse(request: request)
            }
            let notFound = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(#"{"detail":"Not found"}"#.utf8), notFound)
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

    private func listResponse() throws -> Data {
        let payload: [String: Any] = [
            "pagination": [
                "total": libraryItems.count,
                "limit": 20,
                "offset": 0,
                "next": NSNull(),
                "previous": NSNull()
            ],
            "results": libraryItems.map(\.mediaSummaryJSONObject)
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private func bookSearchResponse(for url: URL) throws -> Data {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.queryItems?.first(where: { $0.name == "search" })?.value ?? ""
        let source = components?.queryItems?.first(where: { $0.name == "source" })?.value ?? ""

        guard simulatedBookISBN == query,
              query == Self.matchedFixtureBookISBN
        else {
            return try emptySearchResponse()
        }

        let result = FixtureSearchResult(
            mediaID: "OL27448W",
            source: source.isEmpty ? ProviderSource.openlibrary.rawValue : source,
            title: "Das Glasperlenspiel",
            image: "https://covers.openlibrary.org/b/id/1-L.jpg",
            tracked: false
        )
        return try paginatedSearchResponse(results: [result.mediaSearchJSONObject])
    }

    private func createBookResponse(request: URLRequest) throws -> (Data, URLResponse) {
        let body = request.httpBody ?? Data()
        let decoded = (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
        let source = decoded["source"] as? String ?? ProviderSource.openlibrary.rawValue
        let mediaID = decoded["media_id"] as? String ?? "OL27448W"
        let title = fixtureBookTitle(for: source, mediaID: mediaID)
        let item = FixtureLibraryItem(
            id: nextLibraryID,
            source: source,
            mediaType: "book",
            mediaID: mediaID,
            title: title,
            image: "https://covers.openlibrary.org/b/id/1-L.jpg",
            tracked: true,
            status: 1,
            progress: 0,
            createdAt: "2026-04-11T10:00:00Z"
        )
        nextLibraryID += 1
        libraryItems.append(item)

        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://demo.local/api/v1/media/book/")!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: nil
        )!
        return (try item.mediaSummaryData(), response)
    }

    private func emptySearchResponse() throws -> Data {
        try paginatedSearchResponse(results: [])
    }

    private func paginatedSearchResponse(results: [[String: Any]]) throws -> Data {
        let payload: [String: Any] = [
            "pagination": [
                "total": results.count,
                "limit": 20,
                "offset": 0,
                "next": NSNull(),
                "previous": NSNull()
            ],
            "results": results
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private func fixtureBookTitle(for source: String, mediaID: String) -> String {
        if source == ProviderSource.openlibrary.rawValue || source == ProviderSource.hardcover.rawValue,
           mediaID == "OL27448W" {
            return "Das Glasperlenspiel"
        }

        return "Das Glasperlenspiel"
    }

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

private struct FixtureLibraryItem {
    let id: Int
    let source: String
    let mediaType: String
    let mediaID: String
    let title: String
    let image: String?
    let tracked: Bool
    let status: Int?
    let progress: Int?
    let createdAt: String?

    static let seededManualMovie = FixtureLibraryItem(
        id: 1,
        source: "manual",
        mediaType: "movie",
        mediaID: "1",
        title: "Manual Movie",
        image: nil,
        tracked: true,
        status: 1,
        progress: 42,
        createdAt: "2026-04-11T10:00:00Z"
    )

    var mediaSummaryJSONObject: [String: Any] {
        [
            "id": id,
            "consumption_id": NSNull(),
            "item": [
                "media_id": mediaID,
                "source": source,
                "media_type": mediaType,
                "title": title,
                "image": image as Any? ?? NSNull(),
                "season_number": NSNull(),
                "episode_number": NSNull()
            ],
            "item_id": "\(mediaType)/\(source)/\(mediaID)",
            "parent_id": NSNull(),
            "tracked": tracked,
            "created_at": createdAt ?? NSNull(),
            "score": NSNull(),
            "status": status ?? NSNull(),
            "progress": progress ?? NSNull(),
            "progressed_at": NSNull(),
            "start_date": NSNull(),
            "end_date": NSNull(),
            "notes": NSNull(),
            "lists": []
        ]
    }

    func mediaSummaryData() throws -> Data {
        try JSONSerialization.data(withJSONObject: mediaSummaryJSONObject, options: [])
    }
}

private struct FixtureSearchResult {
    let mediaID: String
    let source: String
    let title: String
    let image: String?
    let tracked: Bool

    var mediaSearchJSONObject: [String: Any] {
        [
            "media_id": mediaID,
            "source": source,
            "media_type": "book",
            "title": title,
            "image": image as Any? ?? NSNull(),
            "tracked": tracked,
            "item_id": NSNull()
        ]
    }
}

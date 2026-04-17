import Foundation
import SwiftUI

@main
struct YamtrackiOSApp: App {
    private let rootView: RootView

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let invalidAuth = arguments.contains("-ui-testing-invalid-auth")
        let useLibraryFixture = arguments.contains("-ui-testing-library-fixture") || arguments.contains("-ui-testing-library-auth-expired")
        let fixtureConfiguration = UITestLibraryFixtureConfiguration(arguments: arguments)
        let shouldUseTestStore = arguments.contains("-ui-testing-persisted-session") || arguments.contains("-ui-testing-invalid-auth") || arguments.contains("-ui-testing-reset-session") || arguments.contains("-ui-testing-library-auth-expired")
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
            apiClient = APIClient(httpClient: UITestLibraryFixtureHTTPClient(configuration: fixtureConfiguration))
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

final class UITestLibraryFixtureHTTPClient: HTTPClient {
    private let state: UITestLibraryFixtureState

    init() {
        state = UITestLibraryFixtureState(configuration: .init(arguments: []))
    }

    fileprivate init(configuration: UITestLibraryFixtureConfiguration) {
        state = UITestLibraryFixtureState(configuration: configuration)
    }

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await state.perform(request)
    }
}

private actor UITestLibraryFixtureState {
    private var items: [UITestTrackedMediaState]
    private let searchableItems: [UITestSearchCatalogItem]
    private var nextDatabaseID: Int
    private var nextManualMediaID: Int
    private let searchErrorMessage: String?
    private var remainingLibraryFailures: Int
    private let isLibraryAuthExpired: Bool
    private var remainingAuthenticatedLibraryLoads: Int
    private let simulatedBookISBN: String?

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    init(configuration: UITestLibraryFixtureConfiguration) {
        searchableItems = [.dune, .glasperlenspiel]
        searchErrorMessage = configuration.searchErrorMessage
        remainingLibraryFailures = configuration.libraryFailureCount
        isLibraryAuthExpired = configuration.libraryAuthExpired
        remainingAuthenticatedLibraryLoads = configuration.libraryAuthExpired ? 1 : 0
        simulatedBookISBN = configuration.simulatedBookISBN

        var initialItems = [UITestTrackedMediaState.manualMovie]
        if configuration.includesTrackedDune {
            initialItems.insert(.trackedDune, at: 0)
        }

        items = initialItems
        nextDatabaseID = (initialItems.map(\.databaseID).max() ?? 0) + 1
        nextManualMediaID = initialItems
            .filter { $0.source == ProviderSource.manual.rawValue }
            .compactMap { Int($0.mediaID) }
            .max()
            .map { $0 + 1 } ?? 1
    }

    func perform(_ request: URLRequest) throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        let method = request.httpMethod ?? "GET"
        let path = normalizedPath(for: url)

        if isLibraryAuthExpired {
            if method == "GET", path == "/api/v1/info" {
                return try response(for: UITestInfoResponse(version: "dev"), url: url)
            }

            if method == "GET", path == "/api/v1/media", remainingAuthenticatedLibraryLoads > 0 {
                remainingAuthenticatedLibraryLoads -= 1
                return try response(for: UITestPaginatedResponse(results: items.map(\.summaryResponse)), url: url)
            }

            return try unauthorizedResponse(url: url)
        }

        switch (method, path) {
        case ("GET", "/api/v1/info"):
            return try response(for: UITestInfoResponse(version: "dev"), url: url)
        case ("GET", "/api/v1/media"):
            if remainingLibraryFailures > 0 {
                remainingLibraryFailures -= 1
                return try errorResponse(message: "Server unreachable", statusCode: 503, url: url)
            }
            return try response(for: UITestPaginatedResponse(results: items.map(\.summaryResponse)), url: url)
        case ("GET", _):
            if let detailRoute = detailRoute(from: path) {
                return try mediaDetailResponse(for: detailRoute, url: url)
            }
            if let searchRoute = searchRoute(from: path) {
                return try mediaSearchResponse(for: searchRoute, url: url)
            }
            return notFoundResponse(url: url)
        case ("POST", _):
            guard let createMediaType = createMediaType(from: path) else {
                return notFoundResponse(url: url)
            }
            return try createMedia(request, mediaType: createMediaType, url: url)
        case ("PATCH", _):
            guard let detailRoute = detailRoute(from: path) else {
                return notFoundResponse(url: url)
            }
            return try updateMedia(request, route: detailRoute, url: url)
        default:
            return notFoundResponse(url: url)
        }
    }

    private func mediaDetailResponse(for route: UITestDetailRoute, url: URL) throws -> (Data, URLResponse) {
        guard route.mediaID.allSatisfy(\.isNumber) else {
            return notFoundResponse(url: url)
        }

        guard let item = items.first(where: { $0.matches(route) }) else {
            return notFoundResponse(url: url)
        }

        return try response(for: item.detailResponse, url: url)
    }

    private func mediaSearchResponse(for route: UITestSearchRoute, url: URL) throws -> (Data, URLResponse) {
        if let searchErrorMessage {
            return try errorResponse(message: searchErrorMessage, statusCode: 503, url: url)
        }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let query = queryItems.first(where: { $0.name == "search" })?.value?.lowercased() ?? ""
        let source = queryItems.first(where: { $0.name == "source" })?.value?.lowercased() ?? ""

        let results = searchableItems
            .filter {
                guard $0.mediaType == route.mediaType, $0.source == source else {
                    return false
                }

                if route.mediaType == MediaType.book.rawValue,
                   let simulatedBookISBN = simulatedBookISBN?.lowercased(),
                   query == simulatedBookISBN
                {
                    return simulatedBookISBN == Self.matchedFixtureBookISBN &&
                        $0.mediaID == UITestSearchCatalogItem.glasperlenspiel.mediaID
                }

                return query.isEmpty || $0.title.lowercased().contains(query) || route.mediaType == MediaType.movie.rawValue
            }
            .map { item in
                UITestSearchResultResponse(
                    mediaID: item.mediaID,
                    source: item.source,
                    mediaType: item.mediaType,
                    title: item.title,
                    image: item.image,
                    tracked: items.contains(where: { $0.matches(item) }),
                    itemID: items.first(where: { $0.matches(item) })?.itemID
                )
            }

        return try response(for: UITestPaginatedResponse(results: results), url: url)
    }

    private func createMedia(_ request: URLRequest, mediaType: String, url: URL) throws -> (Data, URLResponse) {
        let body = try requestBody(request)
        let source = stringValue(body["source"])?.lowercased() ?? ProviderSource.manual.rawValue
        let created: UITestTrackedMediaState

        if source == ProviderSource.manual.rawValue {
            let title = stringValue(body["title"])?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            created = UITestTrackedMediaState(
                databaseID: nextDatabaseID,
                mediaID: String(nextManualMediaID),
                source: source,
                mediaType: mediaType,
                title: title.isEmpty ? "Untitled" : title,
                image: stringValue(body["image"]),
                status: intValue(body["status"]) ?? MediaSummary.Status.planning.rawValue,
                progress: intValue(body["progress"]),
                score: doubleValue(body["score"]),
                notes: stringValue(body["notes"]),
                synopsis: "Manual entry created during UI testing."
            )
            nextManualMediaID += 1
        } else {
            guard
                let mediaID = stringValue(body["media_id"]),
                let catalogItem = searchableItems.first(where: {
                    $0.mediaID == mediaID &&
                    $0.source == source &&
                    $0.mediaType == mediaType
                })
            else {
                return try errorResponse(message: "Fixture search result not found", statusCode: 404, url: url)
            }

            created = UITestTrackedMediaState(
                databaseID: nextDatabaseID,
                mediaID: catalogItem.mediaID,
                source: catalogItem.source,
                mediaType: catalogItem.mediaType,
                title: catalogItem.title,
                image: catalogItem.image,
                status: intValue(body["status"]) ?? MediaSummary.Status.planning.rawValue,
                progress: intValue(body["progress"]),
                score: doubleValue(body["score"]),
                notes: stringValue(body["notes"]),
                synopsis: catalogItem.synopsis
            )
        }

        nextDatabaseID += 1
        items.insert(created, at: 0)
        return try response(for: created.summaryResponse, statusCode: 201, url: url)
    }

    private func updateMedia(_ request: URLRequest, route: UITestDetailRoute, url: URL) throws -> (Data, URLResponse) {
        guard route.mediaID.allSatisfy(\.isNumber) else {
            return notFoundResponse(url: url)
        }

        guard let index = items.firstIndex(where: { $0.matches(route) }) else {
            return notFoundResponse(url: url)
        }

        let body = try requestBody(request)
        items[index].status = intValue(body["status"]) ?? items[index].status
        items[index].progress = intValue(body["progress"]) ?? items[index].progress
        items[index].score = doubleValue(body["score"]) ?? items[index].score
        items[index].notes = stringValue(body["notes"]) ?? items[index].notes

        return try response(for: items[index].detailResponse, url: url)
    }

    private func normalizedPath(for url: URL) -> String {
        var path = url.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    private func requestBody(_ request: URLRequest) throws -> [String: Any] {
        guard let data = request.httpBody, !data.isEmpty else {
            return [:]
        }

        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    private func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private func createMediaType(from path: String) -> String? {
        let components = path.split(separator: "/")
        guard components.count == 4, components[0] == "api", components[1] == "v1", components[2] == "media" else {
            return nil
        }
        return String(components[3])
    }

    private func detailRoute(from path: String) -> UITestDetailRoute? {
        let components = path.split(separator: "/")
        guard components.count == 6, components[0] == "api", components[1] == "v1", components[2] == "media" else {
            return nil
        }

        return UITestDetailRoute(
            mediaType: String(components[3]),
            source: String(components[4]),
            mediaID: String(components[5])
        )
    }

    private func searchRoute(from path: String) -> UITestSearchRoute? {
        let components = path.split(separator: "/")
        guard components.count == 4, components[0] == "api", components[1] == "v1", components[2] == "search" else {
            return nil
        }

        return UITestSearchRoute(mediaType: String(components[3]))
    }

    private func response<Response: Encodable>(
        for responseBody: Response,
        statusCode: Int = 200,
        url: URL
    ) throws -> (Data, URLResponse) {
        let data = try encoder.encode(responseBody)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }

    private func errorResponse(message: String, statusCode: Int, url: URL) throws -> (Data, URLResponse) {
        try response(for: UITestErrorResponse(detail: message), statusCode: statusCode, url: url)
    }

    private func unauthorizedResponse(url: URL) throws -> (Data, URLResponse) {
        try errorResponse(message: "Invalid token", statusCode: 401, url: url)
    }

    private func notFoundResponse(url: URL) -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        return (Data(#"{"detail":"Not found"}"#.utf8), response)
    }

    private static let matchedFixtureBookISBN = "9780306406157"
}

private struct UITestTrackedMediaState {
    let databaseID: Int
    let mediaID: String
    let source: String
    let mediaType: String
    var title: String
    let image: String?
    var status: Int?
    var progress: Int?
    var score: Double?
    var notes: String?
    let synopsis: String

    var itemID: String {
        "\(mediaType)/\(source)/\(mediaID)"
    }

    var summaryResponse: UITestMediaSummaryResponse {
        UITestMediaSummaryResponse(
            id: databaseID,
            consumptionID: nil,
            item: UITestMediaItemResponse(
                mediaID: mediaID,
                source: source,
                mediaType: mediaType,
                title: title,
                image: image,
                seasonNumber: nil,
                episodeNumber: nil
            ),
            itemID: itemID,
            parentID: nil,
            tracked: true,
            createdAt: "2026-04-11T10:00:00Z",
            score: score,
            status: status,
            progress: progress,
            progressedAt: progress == nil ? nil : "2026-04-11T10:30:00Z",
            startDate: nil,
            endDate: nil,
            notes: notes,
            lists: []
        )
    }

    var detailResponse: UITestMediaDetailResponse {
        UITestMediaDetailResponse(
            id: databaseID,
            mediaID: mediaID,
            source: source,
            mediaType: mediaType,
            title: title,
            synopsis: synopsis,
            tracked: true,
            details: UITestDetailMetadata(status: statusTitle, episodes: nil, seasons: nil),
            related: nil,
            consumptions: [
                UITestConsumptionResponse(
                    consumptionID: databaseID * 10,
                    created: "2026-04-11T10:00:00Z",
                    score: score,
                    progress: progress,
                    progressedAt: progress == nil ? nil : "2026-04-11T10:30:00Z",
                    status: status,
                    startDate: nil,
                    endDate: nil,
                    notes: notes
                )
            ],
            lists: []
        )
    }

    var statusTitle: String? {
        guard let status else { return nil }
        return MediaSummary.Status(rawValue: status)?.title
    }

    func matches(_ route: UITestDetailRoute) -> Bool {
        mediaType == route.mediaType && source == route.source && mediaID == route.mediaID
    }

    func matches(_ searchItem: UITestSearchCatalogItem) -> Bool {
        mediaType == searchItem.mediaType && source == searchItem.source && mediaID == searchItem.mediaID
    }

    static let manualMovie = UITestTrackedMediaState(
        databaseID: 1,
        mediaID: "1",
        source: ProviderSource.manual.rawValue,
        mediaType: MediaType.movie.rawValue,
        title: "Manual Movie",
        image: nil,
        status: MediaSummary.Status.inProgress.rawValue,
        progress: 42,
        score: nil,
        notes: nil,
        synopsis: "Fixture-backed movie detail for UI testing."
    )

    static let trackedDune = UITestTrackedMediaState(
        databaseID: 2,
        mediaID: "550",
        source: ProviderSource.tmdb.rawValue,
        mediaType: MediaType.movie.rawValue,
        title: "Dune",
        image: nil,
        status: MediaSummary.Status.planning.rawValue,
        progress: nil,
        score: nil,
        notes: nil,
        synopsis: "Tracked fixture-backed provider result for UI testing."
    )
}

private struct UITestSearchCatalogItem {
    let mediaID: String
    let source: String
    let mediaType: String
    let title: String
    let image: String?
    let synopsis: String

    static let dune = UITestSearchCatalogItem(
        mediaID: "550",
        source: ProviderSource.tmdb.rawValue,
        mediaType: MediaType.movie.rawValue,
        title: "Dune",
        image: nil,
        synopsis: "Fixture-backed provider result for UI testing."
    )

    static let glasperlenspiel = UITestSearchCatalogItem(
        mediaID: "OL27448W",
        source: ProviderSource.openlibrary.rawValue,
        mediaType: MediaType.book.rawValue,
        title: "Das Glasperlenspiel",
        image: nil,
        synopsis: "Fixture-backed Open Library result for UI testing."
    )
}

fileprivate struct UITestLibraryFixtureConfiguration {
    let includesTrackedDune: Bool
    let searchErrorMessage: String?
    let libraryFailureCount: Int
    let libraryAuthExpired: Bool
    let simulatedBookISBN: String?

    init(arguments: [String]) {
        includesTrackedDune = arguments.contains("-ui-testing-tracked-search-result")
        searchErrorMessage = arguments.contains("-ui-testing-search-error") ? "Search service offline" : nil
        libraryFailureCount = arguments.contains("-ui-testing-library-fails-once") ? 1 : 0
        libraryAuthExpired = arguments.contains("-ui-testing-library-auth-expired")
        if let index = arguments.firstIndex(of: "-ui-testing-simulated-book-isbn") {
            let valueIndex = arguments.index(after: index)
            simulatedBookISBN = valueIndex < arguments.endIndex ? arguments[valueIndex] : nil
        } else {
            simulatedBookISBN = nil
        }
    }
}

private struct UITestDetailRoute {
    let mediaType: String
    let source: String
    let mediaID: String
}

private struct UITestSearchRoute {
    let mediaType: String
}

private struct UITestInfoResponse: Encodable {
    let version: String
}

private struct UITestErrorResponse: Encodable {
    let detail: String
}

private struct UITestPaginatedResponse<Item: Encodable>: Encodable {
    let pagination: UITestPaginationResponse
    let results: [Item]

    init(results: [Item]) {
        self.pagination = UITestPaginationResponse(
            total: results.count,
            limit: 20,
            offset: 0,
            next: nil,
            previous: nil
        )
        self.results = results
    }
}

private struct UITestPaginationResponse: Encodable {
    let total: Int
    let limit: Int
    let offset: Int
    let next: String?
    let previous: String?
}

private struct UITestMediaSummaryResponse: Encodable {
    let id: Int
    let consumptionID: Int?
    let item: UITestMediaItemResponse
    let itemID: String
    let parentID: String?
    let tracked: Bool
    let createdAt: String
    let score: Double?
    let status: Int?
    let progress: Int?
    let progressedAt: String?
    let startDate: String?
    let endDate: String?
    let notes: String?
    let lists: [UITestListMembershipResponse]
}

private struct UITestMediaItemResponse: Encodable {
    let mediaID: String
    let source: String
    let mediaType: String
    let title: String
    let image: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
}

private struct UITestMediaDetailResponse: Encodable {
    let id: Int
    let mediaID: String
    let source: String
    let mediaType: String
    let title: String
    let synopsis: String
    let tracked: Bool
    let details: UITestDetailMetadata
    let related: UITestRelatedResponse?
    let consumptions: [UITestConsumptionResponse]
    let lists: [UITestListMembershipResponse]
}

private struct UITestDetailMetadata: Encodable {
    let status: String?
    let episodes: Int?
    let seasons: Int?
}

private struct UITestRelatedResponse: Encodable {
    let seasons: [UITestSeasonResponse]
}

private struct UITestSeasonResponse: Encodable {
    let id: Int
    let item: UITestMediaItemResponse
    let progress: Int?
    let tracked: Bool
    let details: UITestSeasonMetadata
}

private struct UITestSeasonMetadata: Encodable {
    let episodes: Int?
}

private struct UITestConsumptionResponse: Encodable {
    let consumptionID: Int
    let created: String
    let score: Double?
    let progress: Int?
    let progressedAt: String?
    let status: Int?
    let startDate: String?
    let endDate: String?
    let notes: String?
}

private struct UITestSearchResultResponse: Encodable {
    let mediaID: String
    let source: String
    let mediaType: String
    let title: String
    let image: String?
    let tracked: Bool
    let itemID: String?
}

private struct UITestListMembershipResponse: Encodable {
    let listID: Int
    let listItemID: Int
}

import Foundation
import Observation

@MainActor
@Observable
final class LibraryViewModel {
    private let apiClient: APIClient
    private let credentials: SessionCredentials

    var allItems: [MediaSummary] = []
    var selectedFilter: MediaType = .all
    var isLoading = false
    var errorMessage: String?

    init(apiClient: APIClient, credentials: SessionCredentials) {
        self.apiClient = apiClient
        self.credentials = credentials
    }

    func makeDetailViewModel(for item: MediaSummary) -> MediaDetailViewModel? {
        guard
            let nestedItem = item.item,
            !nestedItem.source.isEmpty,
            !nestedItem.mediaType.isEmpty
        else {
            return nil
        }

        return MediaDetailViewModel(
            mediaID: nestedItem.mediaID,
            source: nestedItem.source,
            mediaType: nestedItem.mediaType,
            apiClient: apiClient,
            credentials: credentials
        )
    }

    var items: [MediaSummary] {
        guard selectedFilter != .all else {
            return allItems
        }

        return allItems.filter { $0.mediaType.lowercased() == selectedFilter.rawValue }
    }

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            allItems = try await loadAllPages()
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load library"
        }
    }

    private func loadAllPages() async throws -> [MediaSummary] {
        var items: [MediaSummary] = []
        var request = Endpoint.mediaList()

        while true {
            let response: PaginatedResponse<MediaSummary> = try await apiClient.send(request, credentials: credentials)
            items.append(contentsOf: response.results)

            guard let next = response.pagination.next else {
                return items
            }

            request = try Self.request(from: next)
        }
    }

    private static func request(from nextURLString: String) throws -> APIRequest<PaginatedResponse<MediaSummary>> {
        guard let components = URLComponents(string: nextURLString), !components.path.isEmpty else {
            throw APIError.decoding
        }

        var request = APIRequest<PaginatedResponse<MediaSummary>>(
            path: components.path,
            method: "GET"
        )
        request.queryItems = components.queryItems ?? []
        return request
    }
}

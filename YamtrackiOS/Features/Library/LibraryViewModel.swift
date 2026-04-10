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
            let response: PaginatedResponse<MediaSummary> = try await apiClient.send(Endpoint.mediaList(), credentials: credentials)
            allItems = response.results
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load library"
        }
    }
}

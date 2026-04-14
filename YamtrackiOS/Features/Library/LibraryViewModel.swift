import Foundation
import Observation

@MainActor
@Observable
final class LibraryViewModel {
    private let apiClient: APIClient
    private let credentials: SessionCredentials
    private var addMediaViewModel: AddMediaViewModel?

    var allItems: [MediaSummary] = []
    var selectedFilter: MediaType = .all
    var isLoading = false
    var errorMessage: String?
    var isAuthenticationError = false
    var isShowingAddMedia = false
    var onAuthenticationFailure: (() -> Void)?

    init(apiClient: APIClient, credentials: SessionCredentials) {
        self.apiClient = apiClient
        self.credentials = credentials
    }

    func makeDetailViewModel(for item: MediaSummary) -> MediaDetailViewModel? {
        guard
            let nestedItem = item.item,
            !nestedItem.source.isEmpty,
            !nestedItem.mediaType.isEmpty,
            Self.supportsDetailRoute(mediaID: nestedItem.mediaID)
        else {
            return nil
        }

        let viewModel = MediaDetailViewModel(
            mediaID: nestedItem.mediaID,
            source: nestedItem.source,
            mediaType: nestedItem.mediaType,
            apiClient: apiClient,
            credentials: credentials
        )
        viewModel.onMediaSaved = { [weak self] in
            guard let self else { return }
            Task { await self.load() }
        }
        return viewModel
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
            isAuthenticationError = false
        } catch is CancellationError {
        } catch {
            let isUnauthorized = (error as? APIError) == .unauthorized
            if isUnauthorized {
                onAuthenticationFailure?()
            }
            isAuthenticationError = isUnauthorized
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load library"
        }
    }

    func presentAddMedia() {
        makeAddMediaViewModel().reset()
        isShowingAddMedia = true
    }

    func dismissAddMedia() {
        isShowingAddMedia = false
    }

    func makeAddMediaViewModel() -> AddMediaViewModel {
        if let addMediaViewModel {
            return addMediaViewModel
        }

        let viewModel = AddMediaViewModel(apiClient: apiClient, credentials: credentials)
        viewModel.onMediaCreated = { [weak self] _ in
            guard let self else { return }
            self.dismissAddMedia()
            Task { await self.load() }
        }
        addMediaViewModel = viewModel
        return viewModel
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

    private static func supportsDetailRoute(mediaID: String) -> Bool {
        mediaID.allSatisfy(\.isNumber)
    }
}

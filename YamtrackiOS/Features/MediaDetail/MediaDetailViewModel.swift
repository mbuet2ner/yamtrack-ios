import Foundation
import Observation

@MainActor
@Observable
final class MediaDetailViewModel {
    let mediaID: Int
    let source: String
    let mediaType: String

    private let apiClient: APIClient
    private let credentials: SessionCredentials

    var detail: MediaDetail?
    var errorMessage: String?

    init(
        mediaID: Int,
        source: String,
        mediaType: String,
        apiClient: APIClient,
        credentials: SessionCredentials
    ) {
        self.mediaID = mediaID
        self.source = source
        self.mediaType = mediaType
        self.apiClient = apiClient
        self.credentials = credentials
    }

    var title: String {
        detail?.title ?? ""
    }

    var primaryActionTitle: String {
        mediaType.lowercased() == "tv" ? "Mark Next Episode" : "Update Progress"
    }

    var progressSummary: String? {
        guard let detail else {
            return nil
        }

        switch (detail.progress, detail.totalCount) {
        case let (progress?, total?):
            return "\(progress) of \(total)"
        case let (progress?, nil):
            return String(progress)
        default:
            return nil
        }
    }

    func load() async {
        do {
            detail = try await apiClient.fetchMediaDetail(
                mediaType: mediaType,
                source: source,
                mediaID: mediaID,
                credentials: credentials
            )
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            detail = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load detail"
        }
    }
}

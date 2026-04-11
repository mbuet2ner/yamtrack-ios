import Foundation
import Observation

@MainActor
@Observable
final class RootViewModel {
    private let apiClient: APIClient

    var libraryViewModel: LibraryViewModel?
    var isRestoringSession = true

    init(apiClient: APIClient = .live) {
        self.apiClient = apiClient
    }

    func restoreSession(using session: SessionController) async {
        await session.restoreCredentials()
        syncLibraryShell(using: session)
        isRestoringSession = false
    }

    func sessionDidChange(using session: SessionController) {
        syncLibraryShell(using: session)
    }

    private func syncLibraryShell(using session: SessionController) {
        guard
            session.hasPersistedSession,
            let baseURL = URL(string: session.baseURLString)
        else {
            libraryViewModel = nil
            return
        }

        libraryViewModel = LibraryViewModel(
            apiClient: apiClient,
            credentials: SessionCredentials(baseURL: baseURL, token: session.token)
        )
    }
}

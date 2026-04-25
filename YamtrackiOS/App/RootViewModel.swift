import Foundation
import Observation

@MainActor
@Observable
final class RootViewModel {
    private let apiClient: APIClient
    private var libraryCredentials: SessionCredentials?

    var libraryViewModel: LibraryViewModel?
    var isRestoringSession = true

    init(apiClient: APIClient = .live) {
        self.apiClient = apiClient
    }

    func restoreSession(using session: SessionController) async {
        await session.restoreCredentials()
        if session.hasPersistedSession {
            await session.validatePersistedSession()
        }
        syncLibraryShell(using: session)
        isRestoringSession = false
    }

    func sessionDidChange(using session: SessionController) {
        syncLibraryShell(using: session)
    }

    private func syncLibraryShell(using session: SessionController) {
        guard
            session.connectionStatus == .connected,
            let baseURL = URL(string: session.baseURLString)
        else {
            libraryViewModel = nil
            libraryCredentials = nil
            return
        }

        let credentials = SessionCredentials(baseURL: baseURL, token: session.token)
        if libraryCredentials == credentials, libraryViewModel != nil {
            return
        }

        let libraryViewModel = LibraryViewModel(
            apiClient: apiClient,
            credentials: credentials
        )
        libraryViewModel.onAuthenticationFailure = {
            session.markDisconnected()
        }
        libraryCredentials = credentials
        self.libraryViewModel = libraryViewModel
        Task { await libraryViewModel.load() }
    }
}

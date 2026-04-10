import Foundation
import Observation

@MainActor
@Observable
final class RootViewModel {
    var libraryViewModel: LibraryViewModel?
    var isRestoringSession = true

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
            apiClient: .live,
            credentials: SessionCredentials(baseURL: baseURL, token: session.token)
        )
    }
}

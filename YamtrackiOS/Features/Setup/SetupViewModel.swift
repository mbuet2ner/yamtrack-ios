import Foundation
import Observation

@MainActor
@Observable
final class SetupViewModel {
    private let session: SessionController

    var baseURLString: String
    var token: String
    var errorMessage: String?
    var isConnecting = false

    var canDisconnect: Bool {
        session.hasPersistedSession
    }

    init(session: SessionController) {
        self.session = session
        baseURLString = session.baseURLString
        token = session.token
    }

    func connect() async -> Bool {
        guard !isConnecting else { return false }
        isConnecting = true
        defer { isConnecting = false }

        let previousBaseURLString = session.baseURLString
        let previousToken = session.token
        session.baseURLString = baseURLString
        session.token = token
        errorMessage = nil

        do {
            try await session.connect()
            return true
        } catch {
            session.baseURLString = previousBaseURLString
            session.token = previousToken
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func disconnect() {
        errorMessage = nil
        session.logout()
    }
}

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

    init(session: SessionController) {
        self.session = session
        baseURLString = session.baseURLString
        token = session.token
    }

    func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }

        session.baseURLString = baseURLString
        session.token = token
        errorMessage = nil

        do {
            try await session.connect()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

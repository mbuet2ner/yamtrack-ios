import Foundation
import Observation

private let defaultSessionService = "com.maltepaulbuttner.yamtrackios.session"

enum SessionError: LocalizedError, Equatable {
    case invalidURL
    case invalidToken
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidToken:
            return "Invalid token"
        case .connectionFailed:
            return "Unable to connect"
        }
    }
}

@MainActor
@Observable
final class SessionController {
    static let storageKey = "session"

    private let store: SessionStoring
    private let apiClient: APIClient

    var baseURLString = ""
    var token = ""
    var hasPersistedSession = false

    init(store: SessionStoring, apiClient: APIClient) {
        self.store = store
        self.apiClient = apiClient
    }

    func restoreCredentials() async {
        guard
            let data = try? store.loadValue(for: Self.storageKey),
            let credentials = try? JSONDecoder().decode(SessionCredentials.self, from: data)
        else {
            return
        }

        baseURLString = credentials.baseURL.absoluteString
        token = credentials.token
        hasPersistedSession = true
    }

    func connect() async throws {
        guard let baseURL = URL(string: baseURLString) else {
            throw SessionError.invalidURL
        }

        let credentials = SessionCredentials(baseURL: baseURL, token: token)
        do {
            _ = try await apiClient.fetchInfo(credentials: credentials)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as APIError {
            switch error {
            case .invalidURL:
                throw SessionError.invalidURL
            case .unauthorized:
                throw SessionError.invalidToken
            case .server, .decoding, .transport:
                throw SessionError.connectionFailed
            }
        } catch {
            throw SessionError.connectionFailed
        }

        let data = try JSONEncoder().encode(credentials)
        try store.save(data, for: Self.storageKey)
        hasPersistedSession = true
    }

    func logout() {
        store.deleteValue(for: Self.storageKey)
        baseURLString = ""
        token = ""
        hasPersistedSession = false
    }
}

extension SessionController {
    static func live(
        store: SessionStoring = KeychainStore(service: defaultSessionService, accessGroup: nil),
        apiClient: APIClient = .live
    ) -> SessionController {
        SessionController(
            store: store,
            apiClient: apiClient
        )
    }
}

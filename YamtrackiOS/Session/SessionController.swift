import Foundation
import Observation

private let defaultSessionService = "com.maltepaulbuttner.yamtrackios.session"

enum ConnectionStatus: Equatable {
    case connected
    case disconnected
}

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
    var connectionStatus: ConnectionStatus = .disconnected

    init(store: SessionStoring, apiClient: APIClient) {
        self.store = store
        self.apiClient = apiClient
    }

    func restoreCredentials() async {
        baseURLString = ""
        token = ""
        connectionStatus = .disconnected
        hasPersistedSession = false

        guard
            let data = try? store.loadValue(for: Self.storageKey),
            let credentials = try? JSONDecoder().decode(SessionCredentials.self, from: data)
        else {
            return
        }

        baseURLString = credentials.baseURL.absoluteString
        token = credentials.token
        hasPersistedSession = true
        connectionStatus = .disconnected
    }

    func validatePersistedSession() async {
        guard let credentials = currentCredentials() else {
            connectionStatus = .disconnected
            return
        }

        do {
            _ = try await apiClient.fetchInfo(credentials: credentials)
            connectionStatus = .connected
        } catch is CancellationError {
            return
        } catch {
            connectionStatus = .disconnected
        }
    }

    func connect() async throws {
        guard let credentials = currentCredentials() else {
            throw SessionError.invalidURL
        }

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
        connectionStatus = .connected
    }

    func markDisconnected() {
        connectionStatus = .disconnected
    }

    func logout() {
        store.deleteValue(for: Self.storageKey)
        baseURLString = ""
        token = ""
        hasPersistedSession = false
        connectionStatus = .disconnected
    }

    private func currentCredentials() -> SessionCredentials? {
        guard let baseURL = URL(string: baseURLString) else {
            return nil
        }

        return SessionCredentials(baseURL: baseURL, token: token)
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

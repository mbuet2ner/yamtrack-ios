import Foundation
import Observation

protocol SessionInfoValidating: Sendable {
    func validate(_ request: URLRequest) async throws
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

struct URLSessionSessionInfoValidator: SessionInfoValidating {
    func validate(_ request: URLRequest) async throws {
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SessionError.connectionFailed
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                if httpResponse.statusCode == 401 {
                    throw SessionError.invalidToken
                }
                throw SessionError.connectionFailed
            }
        } catch let error as SessionError {
            throw error
        } catch {
            throw SessionError.connectionFailed
        }
    }
}

@MainActor
@Observable
final class SessionController {
    static let storageKey = "session"
    private static let defaultService = "com.maltepaulbuttner.yamtrackios.session"

    private let store: KeychainStore
    private let validator: SessionInfoValidating

    var baseURLString = ""
    var token = ""
    var hasPersistedSession = false

    init(store: KeychainStore, validator: SessionInfoValidating) {
        self.store = store
        self.validator = validator
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

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw SessionError.invalidURL
        }
        components.path = "/api/v1/info/"
        guard let requestURL = components.url else {
            throw SessionError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        try await validator.validate(request)

        let credentials = SessionCredentials(baseURL: baseURL, token: token)
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
    static func live(validator: SessionInfoValidating = URLSessionSessionInfoValidator()) -> SessionController {
        SessionController(
            store: KeychainStore(service: defaultService, accessGroup: nil),
            validator: validator
        )
    }
}

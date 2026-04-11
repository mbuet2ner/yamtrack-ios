import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case server(String)
    case decoding
    case transport

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .unauthorized:
            return "Invalid token"
        case .server(let detail):
            return detail
        case .decoding:
            return "Unexpected server response"
        case .transport:
            return "Server unreachable"
        }
    }
}

import Foundation

struct SessionCredentials: Codable, Equatable {
    let baseURL: URL
    let token: String
}

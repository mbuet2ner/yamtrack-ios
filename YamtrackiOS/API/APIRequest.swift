import Foundation

struct APIRequest<Response: Decodable> {
    let path: String
    let method: String
    var queryItems: [URLQueryItem] = []
    var body: Data?
}

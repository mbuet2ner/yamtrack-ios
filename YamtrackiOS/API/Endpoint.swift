import Foundation

enum Endpoint {
    static func info() -> APIRequest<InfoResponse> {
        APIRequest(path: "/api/v1/info/", method: "GET")
    }
}

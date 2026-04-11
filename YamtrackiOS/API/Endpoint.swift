import Foundation

enum Endpoint {
    static func info() -> APIRequest<InfoResponse> {
        APIRequest(path: "/api/v1/info/", method: "GET")
    }

    static func mediaList() -> APIRequest<PaginatedResponse<MediaSummary>> {
        APIRequest(path: "/api/v1/media/", method: "GET")
    }

    static func mediaDetail(mediaType: String, source: String, mediaID: String) -> APIRequest<MediaDetail> {
        APIRequest(path: "/api/v1/media/\(mediaType)/\(source)/\(mediaID)/", method: "GET")
    }

    static func mediaSearch(mediaType: MediaType, query: String, source: ProviderSource) -> APIRequest<PaginatedResponse<AddMediaSearchResult>> {
        var request = APIRequest<PaginatedResponse<AddMediaSearchResult>>(
            path: "/api/v1/search/\(mediaType.rawValue)/",
            method: "GET"
        )
        request.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "source", value: source.rawValue)
        ]
        return request
    }

    static func createMedia(mediaType: MediaType, body: Data) -> APIRequest<MediaSummary> {
        var request = APIRequest<MediaSummary>(
            path: "/api/v1/media/\(mediaType.rawValue)/",
            method: "POST"
        )
        request.body = body
        return request
    }

    static func updateMedia(mediaType: String, source: String, mediaID: String, body: Data) -> APIRequest<MediaDetail> {
        var request = APIRequest<MediaDetail>(
            path: "/api/v1/media/\(mediaType)/\(source)/\(mediaID)/",
            method: "PATCH"
        )
        request.body = body
        return request
    }
}

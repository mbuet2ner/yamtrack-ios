import Foundation
import YamtrackOpenAPI

final class APIClient: @unchecked Sendable {
    static let live = APIClient(httpClient: URLSessionHTTPClient())

    private let httpClient: HTTPClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.httpClient = httpClient
        self.decoder = decoder
        self.encoder = encoder
    }

    func fetchInfo(credentials: SessionCredentials) async throws -> InfoResponse {
        let request = try await makeGeneratedURLRequest(credentials: credentials) { client in
            _ = try await client.get_sol_api_sol_v1_sol_info_sol_(.init())
        }
        return try await send(request)
    }

    func fetchMediaList(credentials: SessionCredentials) async throws -> PaginatedResponse<MediaSummary> {
        try await fetchMediaList(limit: nil, offset: nil, credentials: credentials)
    }

    func fetchMediaList(nextPageURL: String, credentials: SessionCredentials) async throws -> PaginatedResponse<MediaSummary> {
        guard let components = URLComponents(string: nextPageURL) else {
            throw APIError.decoding
        }

        let limit = components.queryItems?.first(where: { $0.name == "limit" })?.value.flatMap(Int.init)
        let offset = components.queryItems?.first(where: { $0.name == "offset" })?.value.flatMap(Int.init)
        return try await fetchMediaList(limit: limit, offset: offset, credentials: credentials)
    }

    func fetchMediaDetail(
        mediaType: String,
        source: String,
        mediaID: String,
        credentials: SessionCredentials
    ) async throws -> MediaDetail {
        let request = try await makeGeneratedURLRequest(credentials: credentials) { client in
            _ = try await client.get_sol_api_sol_v1_sol_media_sol__lcub_media_type_rcub__sol__lcub_source_rcub__sol__lcub_media_id_rcub__sol_(
                .init(path: .init(
                    media_type: try Self.mediaType(from: mediaType),
                    source: try Self.source(from: source),
                    media_id: mediaID
                ))
            )
        }
        return try await send(request)
    }

    func searchMedia(
        query: String,
        mediaType: MediaType,
        source: ProviderSource,
        credentials: SessionCredentials
    ) async throws -> [AddMediaSearchResult] {
        let request = try await makeGeneratedURLRequest(credentials: credentials) { client in
            _ = try await client.get_sol_api_sol_v1_sol_search_sol__lcub_media_type_rcub__sol_(
                .init(
                    path: .init(media_type: try Self.mediaType(from: mediaType.rawValue)),
                    query: .init(search: query, source: try Self.source(from: source.rawValue))
                )
            )
        }
        let response: PaginatedResponse<AddMediaSearchResult> = try await send(request)
        return response.results
    }

    func createMedia(_ request: CreateMediaRequest, credentials: SessionCredentials) async throws -> MediaSummary {
        let body = try encoder.encode(request)
        var urlRequest = try await makeGeneratedURLRequest(credentials: credentials) { client in
            _ = try await client.post_sol_api_sol_v1_sol_media_sol__lcub_media_type_rcub__sol_(
                .init(
                    path: .init(media_type: try Self.completeMediaType(from: request.mediaType.rawValue)),
                    body: .json(try Self.generatedCreateBody(from: request))
                )
            )
        }
        urlRequest.httpBody = body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(urlRequest)
    }

    func updateMedia(
        mediaType: String,
        source: String,
        mediaID: String,
        update: MediaUpdateRequest,
        credentials: SessionCredentials
    ) async throws -> MediaDetail {
        let body = try encoder.encode(update)
        var request = try await makeGeneratedURLRequest(credentials: credentials) { client in
            _ = try await client.patch_sol_api_sol_v1_sol_media_sol__lcub_media_type_rcub__sol__lcub_source_rcub__sol__lcub_media_id_rcub__sol_(
                .init(
                    path: .init(
                        media_type: try Self.mediaType(from: mediaType),
                        source: try Self.source(from: source),
                        media_id: mediaID
                    ),
                    body: Self.generatedUpdateBody(update: update)
                )
            )
        }
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(request)
    }

    private func fetchMediaList(
        limit: Int?,
        offset: Int?,
        credentials: SessionCredentials
    ) async throws -> PaginatedResponse<MediaSummary> {
        let request = try await makeGeneratedURLRequest(credentials: credentials) { client in
            _ = try await client.get_sol_api_sol_v1_sol_media_sol_(
                .init(query: .init(limit: limit, offset: offset))
            )
        }
        return try await send(request)
    }

    private func send<Response: Decodable>(_ urlRequest: URLRequest) async throws -> Response {
        do {
            let (data, response) = try await httpClient.perform(urlRequest)
            return try decode(data: data, response: response)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport
        }
    }

    private func makeGeneratedURLRequest(
        credentials: SessionCredentials,
        operation: (YamtrackOpenAPI.Client) async throws -> Void
    ) async throws -> URLRequest {
        let client = try makeGeneratedClient(credentials: credentials)
        do {
            try await operation(client)
        } catch let captured as CapturedOpenAPIRequest {
            return captured.urlRequest
        } catch {
            if let capturedRequest = capturedOpenAPIRequest(from: error) {
                return capturedRequest
            }

            if let apiError = error as? APIError {
                throw apiError
            }

            if error is CancellationError {
                throw CancellationError()
            }

            throw APIError.invalidURL
        }

        throw APIError.transport
    }

    private func makeGeneratedClient(credentials: SessionCredentials) throws -> YamtrackOpenAPI.Client {
        let baseURL = try validatedBaseURL(credentials.baseURL)
        return YamtrackOpenAPI.Client(
            serverURL: baseURL,
            transport: CapturingTransport(),
            middlewares: [BearerAuthMiddleware(token: credentials.token)]
        )
    }

    private func validatedBaseURL(_ baseURL: URL) throws -> URL {
        guard
            let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
            let scheme = components.scheme,
            ["http", "https"].contains(scheme),
            let host = components.host,
            !host.isEmpty
        else {
            throw APIError.invalidURL
        }

        return baseURL
    }

    private static func mediaType(from rawValue: String) throws -> Components.Schemas.MediaTypes {
        guard let mediaType = Components.Schemas.MediaTypes(rawValue: rawValue) else {
            throw APIError.invalidURL
        }
        return mediaType
    }

    private static func completeMediaType(from rawValue: String) throws -> Components.Schemas.MediaTypesComplete {
        guard let mediaType = Components.Schemas.MediaTypesComplete(rawValue: rawValue) else {
            throw APIError.invalidURL
        }
        return mediaType
    }

    private static func source(from rawValue: String) throws -> Components.Schemas.Source {
        guard let source = Components.Schemas.Source(rawValue: rawValue) else {
            throw APIError.invalidURL
        }
        return source
    }

    private static func status(from status: MediaSummary.Status?) -> Components.Schemas.MediaStatus? {
        status.flatMap { Components.Schemas.MediaStatus(rawValue: $0.rawValue) }
    }

    private static func generatedCreateBody(from request: CreateMediaRequest) throws -> Components.Schemas.CreateMedia {
        switch request {
        case let .manual(_, title, imageURL, status, progress, score, notes):
            return Components.Schemas.CreateMedia(
                source: .manual,
                title: title,
                image: imageURL,
                score: score.map(Float.init),
                status: Self.status(from: status),
                progress: progress,
                notes: notes
            )
        case let .provider(_, source, mediaID, status, progress, score, notes):
            return Components.Schemas.CreateMedia(
                source: try Self.source(from: source.rawValue),
                media_id: mediaID,
                score: score.map(Float.init),
                status: Self.status(from: status),
                progress: progress,
                notes: notes
            )
        }
    }

    private static func generatedUpdateBody(
        update: MediaUpdateRequest
    ) -> Operations.patch_sol_api_sol_v1_sol_media_sol__lcub_media_type_rcub__sol__lcub_source_rcub__sol__lcub_media_id_rcub__sol_.Input.Body {
        .json(.UpdateBook(.init(
            score: update.score.map(Float.init),
            status: Self.status(from: update.status),
            progress: update.progress,
            notes: update.notes
        )))
    }

    private func decode<Response: Decodable>(data: Data, response: URLResponse) throws -> Response {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.transport
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let detail = parseErrorDetail(from: data)

            if httpResponse.statusCode == 401 || (httpResponse.statusCode == 403 && detail?.localizedCaseInsensitiveContains("invalid token") == true) {
                throw APIError.unauthorized
            }

            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = detail?.isEmpty == false
                ? detail ?? ""
                : body?.isEmpty == false
                ? body ?? ""
                : HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIError.server(message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func parseErrorDetail(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = object["detail"] as? String
        else {
            return nil
        }

        return detail.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

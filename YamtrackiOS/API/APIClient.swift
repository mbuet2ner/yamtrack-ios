import Foundation

final class APIClient {
    private let httpClient: HTTPClient
    private let decoder: JSONDecoder

    init(httpClient: HTTPClient = URLSessionHTTPClient(), decoder: JSONDecoder = JSONDecoder()) {
        self.httpClient = httpClient
        self.decoder = decoder
    }

    func fetchInfo(credentials: SessionCredentials) async throws -> InfoResponse {
        try await send(Endpoint.info(), credentials: credentials)
    }

    private func send<Response: Decodable>(
        _ request: APIRequest<Response>,
        credentials: SessionCredentials
    ) async throws -> Response {
        let urlRequest = try makeURLRequest(request, credentials: credentials)

        do {
            let (data, response) = try await httpClient.perform(urlRequest)
            return try decode(data: data, response: response)
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport
        }
    }

    private func makeURLRequest<Response: Decodable>(
        _ request: APIRequest<Response>,
        credentials: SessionCredentials
    ) throws -> URLRequest {
        guard var components = URLComponents(url: credentials.baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        components.path = credentials.baseURL.path + request.path
        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        if let body = request.body {
            urlRequest.httpBody = body
        }

        return urlRequest
    }

    private func decode<Response: Decodable>(data: Data, response: URLResponse) throws -> Response {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.transport
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = body?.isEmpty == false
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
}

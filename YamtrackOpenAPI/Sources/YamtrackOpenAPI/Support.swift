import Foundation
import HTTPTypes
import OpenAPIRuntime

public final class CapturedOpenAPIRequest: Error, @unchecked Sendable {
    public let urlRequest: URLRequest

    init(urlRequest: URLRequest) {
        self.urlRequest = urlRequest
    }
}

public func capturedOpenAPIRequest(from error: any Error) -> URLRequest? {
    if let captured = error as? CapturedOpenAPIRequest {
        return captured.urlRequest
    }

    if let clientError = error as? ClientError {
        return capturedOpenAPIRequest(from: clientError.underlyingError)
    }

    return nil
}

public struct CapturingTransport: ClientTransport {
    public init() {}

    public func send(
        _ request: HTTPRequest,
        body requestBody: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var urlRequest = try URLRequest(openAPIRequest: request, baseURL: baseURL)
        if let requestBody {
            urlRequest.httpBody = try await Data(collecting: requestBody, upTo: .max)
        }
        throw CapturedOpenAPIRequest(urlRequest: urlRequest)
    }
}

public struct BearerAuthMiddleware: ClientMiddleware {
    private let token: String

    public init(token: String) {
        self.token = token
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(token)"
        return try await next(request, body, baseURL)
    }
}

private extension URLRequest {
    init(openAPIRequest request: HTTPRequest, baseURL: URL) throws {
        guard
            var baseComponents = URLComponents(string: baseURL.absoluteString),
            let requestComponents = URLComponents(string: request.path ?? "")
        else {
            throw URLError(.badURL)
        }

        baseComponents.percentEncodedPath = Self.normalizedPath(
            basePath: baseComponents.percentEncodedPath,
            requestPath: requestComponents.percentEncodedPath
        )
        baseComponents.percentEncodedQuery = requestComponents.percentEncodedQuery

        guard let url = baseComponents.url else {
            throw URLError(.badURL)
        }

        self.init(url: url)
        httpMethod = request.method.rawValue
        allHTTPHeaderFields = Dictionary(
            uniqueKeysWithValues: request.headerFields.map { field in
                (field.name.rawName, field.value)
            }
        )
    }

    private static func normalizedPath(basePath: String, requestPath: String) -> String {
        let trimmedBase = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
        let prefixedRequest = requestPath.hasPrefix("/") ? requestPath : "/\(requestPath)"
        return "\(trimmedBase)\(prefixedRequest)"
    }
}

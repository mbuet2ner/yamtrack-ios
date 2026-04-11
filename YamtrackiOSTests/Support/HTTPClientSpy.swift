import Foundation
@testable import YamtrackiOS

final class HTTPClientSpy: HTTPClient {
    private let result: Result<(Data, URLResponse), Error>
    private(set) var lastRequest: URLRequest?

    init(result: Result<(Data, URLResponse), Error>) {
        self.result = result
    }

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        return try result.get()
    }
}

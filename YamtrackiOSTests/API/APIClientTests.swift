import XCTest
@testable import YamtrackiOS

final class APIClientTests: XCTestCase {
    func test_fetchInfo_sendsBearerTokenAndDecodesPayload() async throws {
        let fixtureData = try loadFixtureData(named: "info")
        let response = HTTPURLResponse(
            url: URL(string: "https://demo.local/api/v1/info/")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let spy = HTTPClientSpy(result: .success((fixtureData, response)))
        let sut = APIClient(httpClient: spy)
        let credentials = SessionCredentials(
            baseURL: URL(string: "https://demo.local")!,
            token: "secret"
        )

        let info = try await sut.fetchInfo(credentials: credentials)

        XCTAssertEqual(spy.lastRequest?.url?.absoluteString, "https://demo.local/api/v1/info/")
        XCTAssertEqual(spy.lastRequest?.httpMethod, "GET")
        XCTAssertEqual(spy.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(info.name, "Yamtrack")
        XCTAssertEqual(info.version, "0.0.24")
    }

    func test_fetchInfo_throwsUnauthorizedFor401() async throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://demo.local/api/v1/info/")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        let spy = HTTPClientSpy(result: .success((Data(), response)))
        let sut = APIClient(httpClient: spy)
        let credentials = SessionCredentials(
            baseURL: URL(string: "https://demo.local")!,
            token: "secret"
        )

        do {
            _ = try await sut.fetchInfo(credentials: credentials)
            XCTFail("Expected unauthorized error")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        }
    }
}

private func loadFixtureData(named name: String) throws -> Data {
    let bundle = Bundle(for: APIClientTests.self)
    let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

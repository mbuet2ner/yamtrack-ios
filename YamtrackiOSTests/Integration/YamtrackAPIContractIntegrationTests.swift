import XCTest
@testable import YamtrackiOS

final class YamtrackAPIContractIntegrationTests: XCTestCase {
    func test_fetchInfo_decodesLiveInfoContract() async throws {
        let harness = try Self.makeHarness()

        let info = try await harness.apiClient.fetchInfo(credentials: harness.credentials)

        XCTAssertFalse(info.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func test_mediaList_decodesLivePaginatedContract() async throws {
        let harness = try Self.makeHarness()

        let response: PaginatedResponse<MediaSummary> = try await harness.apiClient.send(
            Endpoint.mediaList(),
            credentials: harness.credentials
        )

        XCTAssertGreaterThanOrEqual(response.pagination.total, 0)
        XCTAssertGreaterThanOrEqual(response.pagination.limit, 0)
        XCTAssertGreaterThanOrEqual(response.pagination.offset, 0)
        XCTAssertLessThanOrEqual(response.results.count, response.pagination.limit)

        for summary in response.results {
            XCTAssertNotNil(summary.item, "The library list contract should include a nested item payload.")
            XCTAssertFalse(summary.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(summary.mediaType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func test_nonNumericProviderDetailRoute_documentsCurrentBackend404Limitation() async throws {
        let harness = try Self.makeHarness()
        let route = try Self.makeNonNumericDetailRoute()
        let url = try Self.makeNonNumericDetailURL(route: route, baseURL: harness.credentials.baseURL)

        var request = URLRequest(url: url)
        request.setValue("Bearer \(harness.credentials.token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Expected an HTTP response for the non-numeric provider detail route.")
            return
        }

        XCTAssertEqual(
            httpResponse.statusCode,
            404,
            "Expected Yamtrack to reject non-numeric provider detail routes until the backend route regex is widened."
        )
    }
}

private extension YamtrackAPIContractIntegrationTests {
    struct Harness {
        let apiClient: APIClient
        let credentials: SessionCredentials
    }

    struct NonNumericDetailRoute {
        let mediaType: String
        let source: String
        let mediaID: String
    }

    static func makeHarness() throws -> Harness {
        let environment = ProcessInfo.processInfo.environment
        let baseURLString = environment["YAMTRACK_TEST_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = environment["YAMTRACK_TEST_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let baseURLString, !baseURLString.isEmpty, let token, !token.isEmpty else {
            throw XCTSkip("Set YAMTRACK_TEST_BASE_URL and YAMTRACK_TEST_TOKEN to run Yamtrack backend integration tests.")
        }

        guard let baseURL = URL(string: baseURLString) else {
            XCTFail("YAMTRACK_TEST_BASE_URL must be a valid URL.")
            throw IntegrationConfigurationError.invalidBaseURL
        }

        return Harness(
            apiClient: .live,
            credentials: SessionCredentials(baseURL: baseURL, token: token)
        )
    }

    static func makeNonNumericDetailRoute() throws -> NonNumericDetailRoute {
        let environment = ProcessInfo.processInfo.environment
        let mediaType = environment["YAMTRACK_TEST_NON_NUMERIC_MEDIA_TYPE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = environment["YAMTRACK_TEST_NON_NUMERIC_SOURCE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let mediaID = environment["YAMTRACK_TEST_NON_NUMERIC_MEDIA_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let mediaType, !mediaType.isEmpty,
            let source, !source.isEmpty,
            let mediaID, !mediaID.isEmpty
        else {
            throw XCTSkip("""
            Set YAMTRACK_TEST_NON_NUMERIC_MEDIA_TYPE, YAMTRACK_TEST_NON_NUMERIC_SOURCE, and \
            YAMTRACK_TEST_NON_NUMERIC_MEDIA_ID for a tracked provider item to exercise the documented \
            non-numeric detail route limitation without creating or updating media.
            """)
        }

        guard mediaID.contains(where: { !$0.isNumber }) else {
            XCTFail("YAMTRACK_TEST_NON_NUMERIC_MEDIA_ID must contain at least one non-numeric character.")
            throw IntegrationConfigurationError.numericProviderMediaID
        }

        return NonNumericDetailRoute(mediaType: mediaType, source: source, mediaID: mediaID)
    }

    static func makeNonNumericDetailURL(route: NonNumericDetailRoute, baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            XCTFail("YAMTRACK_TEST_BASE_URL must be a valid URL.")
            throw IntegrationConfigurationError.invalidBaseURL
        }

        components.path = baseURL.path + "/api/v1/media/\(route.mediaType)/\(route.source)/\(route.mediaID)/"
        guard let url = components.url else {
            XCTFail("YAMTRACK_TEST_NON_NUMERIC_* values must build a valid detail URL.")
            throw IntegrationConfigurationError.invalidDetailURL
        }

        return url
    }

    enum IntegrationConfigurationError: Error {
        case invalidBaseURL
        case invalidDetailURL
        case numericProviderMediaID
    }
}

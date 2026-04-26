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

        let response = try await harness.apiClient.fetchMediaList(credentials: harness.credentials)

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

    func test_nonNumericProviderDetailRouteDecodesTrackedItem() async throws {
        let harness = try Self.makeHarness()
        let route = try Self.makeNonNumericDetailRoute()

        let detail = try await harness.apiClient.fetchMediaDetail(
            mediaType: route.mediaType,
            source: route.source,
            mediaID: route.mediaID,
            credentials: harness.credentials
        )

        XCTAssertEqual(detail.mediaID, route.mediaID)
        XCTAssertEqual(detail.source, route.source)
        XCTAssertEqual(detail.mediaType, route.mediaType)
        XCTAssertFalse(detail.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            YAMTRACK_TEST_NON_NUMERIC_MEDIA_ID for a tracked provider item to verify the widened \
            non-numeric detail route without creating or updating media.
            """)
        }

        guard mediaID.contains(where: { !$0.isNumber }) else {
            XCTFail("YAMTRACK_TEST_NON_NUMERIC_MEDIA_ID must contain at least one non-numeric character.")
            throw IntegrationConfigurationError.numericProviderMediaID
        }

        return NonNumericDetailRoute(mediaType: mediaType, source: source, mediaID: mediaID)
    }

    enum IntegrationConfigurationError: Error {
        case invalidBaseURL
        case numericProviderMediaID
    }
}

import XCTest
@testable import YamtrackiOS

final class ISBNPerformanceTests: XCTestCase {
    private static let expectedNormalizedCount = 1_200
    private static let batchBudgetSeconds = 0.25

    func test_normalizeISBNBatchPerformance() {
        let samples = Self.makeBarcodeSamples()

        XCTAssertEqual(Self.normalizedISBNCount(in: samples), Self.expectedNormalizedCount)

        measure {
            XCTAssertEqual(Self.normalizedISBNCount(in: samples), Self.expectedNormalizedCount)
        }
    }

    func test_normalizeISBNBatchCompletesWithinBudget() {
        let samples = Self.makeBarcodeSamples()

        let start = CFAbsoluteTimeGetCurrent()
        let normalizedCount = Self.normalizedISBNCount(in: samples)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(normalizedCount, Self.expectedNormalizedCount)
        XCTAssertLessThan(elapsed, Self.batchBudgetSeconds)
    }

    private static func makeBarcodeSamples() -> [String] {
        let seedValues = [
            "978-0-306-40615-7",
            " 9780306406157 ",
            "0-8044-2957-X",
            "9780306406158",
            "not-an-isbn"
        ]

        return (0..<2_000).map { seedValues[$0 % seedValues.count] }
    }

    private static func normalizedISBNCount(in values: [String]) -> Int {
        values.reduce(0) { count, value in
            ISBN.normalize(value) == nil ? count : count + 1
        }
    }
}

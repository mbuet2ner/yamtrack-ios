import XCTest
@testable import YamtrackiOS

final class ISBNTests: XCTestCase {
    func test_normalizeTrimsSeparatorsFromValidISBN13() {
        XCTAssertEqual(ISBN.normalize("978-0-306-40615-7"), "9780306406157")
    }

    func test_normalizeAcceptsValidISBN10WithXChecksum() {
        XCTAssertEqual(ISBN.normalize("0-8044-2957-X"), "080442957X")
    }

    func test_normalizeRejectsInvalidISBN() {
        XCTAssertNil(ISBN.normalize("9780306406158"))
        XCTAssertFalse(ISBN.isValid("9780306406158"))
    }
}

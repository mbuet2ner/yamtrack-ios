import Foundation

protocol SessionStoring: Sendable {
    func save(_ data: Data, for key: String) throws
    func loadValue(for key: String) throws -> Data?
    func deleteValue(for key: String)
}

final class InMemorySessionStore: SessionStoring, @unchecked Sendable {
    private var values: [String: Data] = [:]

    func save(_ data: Data, for key: String) throws {
        values[key] = data
    }

    func loadValue(for key: String) throws -> Data? {
        values[key]
    }

    func deleteValue(for key: String) {
        values[key] = nil
    }
}

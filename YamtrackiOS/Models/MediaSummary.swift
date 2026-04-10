import Foundation

enum MediaType: String, Codable, CaseIterable, Identifiable {
    case all
    case movie
    case tv
    case anime
    case manga
    case game
    case book
    case comic
    case boardgame

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .movie:
            return "Movies"
        case .tv:
            return "TV"
        case .anime:
            return "Anime"
        case .manga:
            return "Manga"
        case .game:
            return "Games"
        case .book:
            return "Books"
        case .comic:
            return "Comics"
        case .boardgame:
            return "Board Games"
        }
    }
}

struct PaginatedResponse<Item: Decodable>: Decodable {
    let results: [Item]
}

struct MediaSummary: Decodable, Equatable, Identifiable {
    let mediaID: Int
    let title: String
    let mediaType: String
    let status: String?
    let progressLabel: String?

    var id: Int { mediaID }
}

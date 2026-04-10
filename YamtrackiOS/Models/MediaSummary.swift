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

struct Pagination: Decodable, Equatable {
    let total: Int
    let limit: Int
    let offset: Int
    let next: String?
    let previous: String?
}

struct PaginatedResponse<Item: Decodable>: Decodable {
    let pagination: Pagination
    let results: [Item]
}

struct MediaSummary: Decodable, Equatable, Identifiable {
    struct Item: Decodable, Equatable {
        let mediaID: Int
        let source: String
        let mediaType: String
        let title: String
        let image: String?
        let seasonNumber: Int?
        let episodeNumber: Int?

        enum CodingKeys: String, CodingKey {
            case mediaID = "media_id"
            case source
            case mediaType = "media_type"
            case title
            case image
            case seasonNumber = "season_number"
            case episodeNumber = "episode_number"
        }
    }

    enum Status: Int, Decodable {
        case planning = 0
        case inProgress = 1
        case paused = 2
        case completed = 3
        case dropped = 4

        var title: String {
            switch self {
            case .planning:
                return "Planning"
            case .inProgress:
                return "In progress"
            case .paused:
                return "Paused"
            case .completed:
                return "Completed"
            case .dropped:
                return "Dropped"
            }
        }
    }

    struct ListMembership: Decodable, Equatable {
        let listID: Int
        let listItemID: Int

        enum CodingKeys: String, CodingKey {
            case listID = "list_id"
            case listItemID = "list_item_id"
        }
    }

    let databaseID: Int?
    let consumptionID: Int?
    let item: Item?
    let itemID: String?
    let parentID: String?
    let tracked: Bool
    let createdAt: String?
    let score: Double?
    let status: Status?
    let progress: Int?
    let progressedAt: String?
    let startDate: String?
    let endDate: String?
    let notes: String?
    let lists: [ListMembership]

    var id: Int {
        databaseID ?? item?.mediaID ?? 0
    }

    var title: String {
        item?.title ?? ""
    }

    var mediaType: String {
        item?.mediaType ?? ""
    }

    var statusLabel: String? {
        status?.title
    }

    var progressLabel: String? {
        progress.map(String.init)
    }

    enum CodingKeys: String, CodingKey {
        case databaseID = "id"
        case consumptionID = "consumption_id"
        case item
        case itemID = "item_id"
        case parentID = "parent_id"
        case tracked
        case createdAt = "created_at"
        case score
        case status
        case progress
        case progressedAt = "progressed_at"
        case startDate = "start_date"
        case endDate = "end_date"
        case notes
        case lists
    }
}

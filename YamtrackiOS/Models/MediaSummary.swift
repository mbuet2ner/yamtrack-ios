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

    var singularTitle: String {
        switch self {
        case .all:
            return "Media"
        case .movie:
            return "Movie"
        case .tv:
            return "TV Show"
        case .anime:
            return "Anime"
        case .manga:
            return "Manga"
        case .game:
            return "Game"
        case .book:
            return "Book"
        case .comic:
            return "Comic"
        case .boardgame:
            return "Board Game"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "square.stack.3d.up.fill"
        case .movie:
            return "film.fill"
        case .tv:
            return "tv.fill"
        case .anime:
            return "sparkles"
        case .manga:
            return "book.closed.fill"
        case .game:
            return "gamecontroller.fill"
        case .book:
            return "books.vertical.fill"
        case .comic:
            return "newspaper.fill"
        case .boardgame:
            return "die.face.5.fill"
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
        let mediaID: String
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

        init(
            mediaID: String,
            source: String,
            mediaType: String,
            title: String,
            image: String?,
            seasonNumber: Int?,
            episodeNumber: Int?
        ) {
            self.mediaID = mediaID
            self.source = source
            self.mediaType = mediaType
            self.title = title
            self.image = image
            self.seasonNumber = seasonNumber
            self.episodeNumber = episodeNumber
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let numericID = try? container.decode(Int.self, forKey: .mediaID) {
                mediaID = String(numericID)
            } else {
                mediaID = try container.decode(String.self, forKey: .mediaID)
            }
            source = try container.decode(String.self, forKey: .source)
            mediaType = try container.decode(String.self, forKey: .mediaType)
            title = try container.decode(String.self, forKey: .title)
            image = try container.decodeIfPresent(String.self, forKey: .image)
            seasonNumber = try container.decodeIfPresent(Int.self, forKey: .seasonNumber)
            episodeNumber = try container.decodeIfPresent(Int.self, forKey: .episodeNumber)
        }
    }

    enum Status: Int, Codable, CaseIterable {
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
        databaseID ?? 0
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

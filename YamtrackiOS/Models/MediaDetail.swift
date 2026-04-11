import Foundation

struct MediaDetail: Decodable, Equatable, Identifiable {
    struct SeasonDetail: Decodable, Equatable, Identifiable {
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

        struct Details: Decodable, Equatable {
            let episodes: Int?
        }

        let id: Int
        let item: Item
        let progress: Int?
        let tracked: Bool
        let totalEpisodes: Int?

        var title: String { item.title }
        var seasonNumber: Int? { item.seasonNumber }

        enum CodingKeys: String, CodingKey {
            case id
            case item
            case progress
            case tracked
            case details
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            item = try container.decode(Item.self, forKey: .item)
            progress = try container.decodeIfPresent(Int.self, forKey: .progress)
            tracked = try container.decodeIfPresent(Bool.self, forKey: .tracked) ?? false
            totalEpisodes = try container.decodeIfPresent(Details.self, forKey: .details)?.episodes
        }
    }

    private struct DetailMetadata: Decodable, Equatable {
        let status: String?
        let episodes: Int?
        let seasons: Int?
    }

    private struct ConsumptionDetail: Decodable, Equatable {
        let score: Double?
        let progress: Int?
        let status: MediaSummary.Status?
        let notes: String?
    }

    private struct RelatedDetail: Decodable, Equatable {
        let seasons: [SeasonDetail]?
    }

    let mediaID: String
    let source: String
    let mediaType: String
    let title: String
    let status: String?
    let overview: String?
    let tracked: Bool
    let seasons: [SeasonDetail]?

    private let metadata: DetailMetadata?
    private let consumptions: [ConsumptionDetail]

    var id: String { "\(source)-\(mediaType)-\(mediaID)" }
    var progress: Int? { consumptions.last?.progress }
    var score: Double? { consumptions.last?.score }
    var trackingStatus: MediaSummary.Status? { consumptions.last?.status }
    var notes: String? { consumptions.last?.notes }
    var totalCount: Int? { metadata?.episodes ?? metadata?.seasons }

    enum CodingKeys: String, CodingKey {
        case mediaID = "media_id"
        case source
        case mediaType = "media_type"
        case title
        case overview = "synopsis"
        case tracked
        case metadata = "details"
        case related
        case consumptions
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
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        tracked = try container.decodeIfPresent(Bool.self, forKey: .tracked) ?? false
        metadata = try container.decodeIfPresent(DetailMetadata.self, forKey: .metadata)
        seasons = try container.decodeIfPresent(RelatedDetail.self, forKey: .related)?.seasons
        consumptions = try container.decodeIfPresent([ConsumptionDetail].self, forKey: .consumptions) ?? []
        status = metadata?.status
    }
}

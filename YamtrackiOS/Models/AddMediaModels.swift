import Foundation

enum ProviderSource: String, Codable, CaseIterable, Identifiable {
    case tmdb
    case mal
    case mangaupdates
    case igdb
    case openlibrary
    case hardcover
    case comicvine
    case bgg
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tmdb:
            return "TMDB"
        case .mal:
            return "MyAnimeList"
        case .mangaupdates:
            return "MangaUpdates"
        case .igdb:
            return "IGDB"
        case .openlibrary:
            return "Open Library"
        case .hardcover:
            return "Hardcover"
        case .comicvine:
            return "Comic Vine"
        case .bgg:
            return "BoardGameGeek"
        case .manual:
            return "Manual"
        }
    }

    static func supportedSources(for mediaType: MediaType) -> [ProviderSource] {
        switch mediaType {
        case .movie, .tv:
            return [.tmdb, .manual]
        case .anime:
            return [.mal, .manual]
        case .manga:
            return [.mal, .mangaupdates, .manual]
        case .game:
            return [.igdb, .manual]
        case .book:
            return [.openlibrary, .hardcover, .manual]
        case .comic:
            return [.comicvine, .manual]
        case .boardgame:
            return [.bgg, .manual]
        case .all:
            return [.manual]
        }
    }

    static func preferredSearchSource(for mediaType: MediaType) -> ProviderSource? {
        supportedSources(for: mediaType).first { $0 != .manual }
    }

    var systemImage: String {
        switch self {
        case .tmdb:
            return "film.stack.fill"
        case .mal:
            return "sparkles"
        case .mangaupdates:
            return "text.page.fill"
        case .igdb:
            return "gamecontroller.fill"
        case .openlibrary:
            return "books.vertical.fill"
        case .hardcover:
            return "book.closed.fill"
        case .comicvine:
            return "newspaper.fill"
        case .bgg:
            return "die.face.5.fill"
        case .manual:
            return "pencil.and.outline"
        }
    }
}

extension Optional where Wrapped == MediaType {
    var singularTitle: String {
        self?.singularTitle ?? MediaType.all.singularTitle
    }

    var systemImage: String {
        self?.systemImage ?? MediaType.all.systemImage
    }
}

extension Optional where Wrapped == ProviderSource {
    var title: String {
        self?.title ?? "Source"
    }

    var systemImage: String {
        self?.systemImage ?? "square.stack.3d.up.fill"
    }
}

struct AddMediaSearchResult: Decodable, Equatable, Identifiable {
    let mediaID: String
    let source: String
    let mediaType: String
    let title: String
    let image: String?
    let tracked: Bool
    let itemID: String?

    var id: String { "\(mediaType)-\(source)-\(mediaID)" }

    enum CodingKeys: String, CodingKey {
        case mediaID = "media_id"
        case source
        case mediaType = "media_type"
        case title
        case image
        case tracked
        case itemID = "item_id"
    }

    init(
        mediaID: String,
        source: String,
        mediaType: String,
        title: String,
        image: String?,
        tracked: Bool,
        itemID: String?
    ) {
        self.mediaID = mediaID
        self.source = source
        self.mediaType = mediaType
        self.title = title
        self.image = image
        self.tracked = tracked
        self.itemID = itemID
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
        tracked = try container.decodeIfPresent(Bool.self, forKey: .tracked) ?? false
        itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
    }
}

enum CreateMediaRequest: Encodable, Equatable {
    case manual(
        mediaType: MediaType,
        title: String,
        imageURL: String?,
        status: MediaSummary.Status?,
        progress: Int?,
        score: Double?,
        notes: String?
    )
    case provider(
        mediaType: MediaType,
        source: ProviderSource,
        mediaID: String,
        status: MediaSummary.Status?,
        progress: Int?,
        score: Double?,
        notes: String?
    )

    var mediaType: MediaType {
        switch self {
        case let .manual(mediaType, _, _, _, _, _, _),
             let .provider(mediaType, _, _, _, _, _, _):
            return mediaType
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)

        switch self {
        case let .manual(_, title, imageURL, status, progress, score, notes):
            try container.encode(ProviderSource.manual.rawValue, forKey: .init("source"))
            try container.encode(title, forKey: .init("title"))
            try container.encodeIfPresent(imageURL, forKey: .init("image"))
            try container.encodeIfPresent(status?.rawValue, forKey: .init("status"))
            try container.encodeIfPresent(progress, forKey: .init("progress"))
            try container.encodeIfPresent(score, forKey: .init("score"))
            try container.encodeIfPresent(notes, forKey: .init("notes"))
        case let .provider(_, source, mediaID, status, progress, score, notes):
            try container.encode(source.rawValue, forKey: .init("source"))
            try container.encode(mediaID, forKey: .init("media_id"))
            try container.encodeIfPresent(status?.rawValue, forKey: .init("status"))
            try container.encodeIfPresent(progress, forKey: .init("progress"))
            try container.encodeIfPresent(score, forKey: .init("score"))
            try container.encodeIfPresent(notes, forKey: .init("notes"))
        }
    }
}

struct MediaUpdateRequest: Encodable, Equatable {
    let status: MediaSummary.Status?
    let progress: Int?
    let score: Double?
    let notes: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        try container.encodeIfPresent(status?.rawValue, forKey: .init("status"))
        try container.encodeIfPresent(progress, forKey: .init("progress"))
        try container.encodeIfPresent(score, forKey: .init("score"))
        try container.encodeIfPresent(notes, forKey: .init("notes"))
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        return nil
    }
}

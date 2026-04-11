import Foundation
import Observation

@MainActor
@Observable
final class AddMediaViewModel {
    private let apiClient: APIClient
    private let credentials: SessionCredentials

    var selectedType: MediaType = .movie {
        didSet {
            let sources = availableSources
            if !sources.contains(selectedSource) {
                selectedSource = sources.first ?? .manual
            }
            selectedResult = nil
            results = []
        }
    }
    var selectedSource: ProviderSource = .tmdb {
        didSet {
            selectedResult = nil
            results = []
        }
    }
    var query = ""
    var results: [AddMediaSearchResult] = []
    var selectedResult: AddMediaSearchResult?
    var manualTitle = ""
    var manualImageURL = ""
    var manualProgress = ""
    var manualScore = ""
    var manualNotes = ""
    var manualStatus: MediaSummary.Status = .planning
    var isSearching = false
    var isCreating = false
    var errorMessage: String?
    var onMediaCreated: ((MediaSummary) -> Void)?

    init(apiClient: APIClient, credentials: SessionCredentials) {
        self.apiClient = apiClient
        self.credentials = credentials
    }

    var availableTypes: [MediaType] {
        [.movie, .tv, .anime, .manga, .game, .book, .comic, .boardgame]
    }

    var availableSources: [ProviderSource] {
        ProviderSource.supportedSources(for: selectedType)
    }

    var isManualSource: Bool {
        selectedSource == .manual
    }

    func reset() {
        selectedType = .movie
        selectedSource = .tmdb
        query = ""
        results = []
        selectedResult = nil
        manualTitle = ""
        manualImageURL = ""
        manualProgress = ""
        manualScore = ""
        manualNotes = ""
        manualStatus = .planning
        isSearching = false
        isCreating = false
        errorMessage = nil
    }

    func search() async {
        guard !isManualSource else { return }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            selectedResult = nil
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            results = try await apiClient.searchMedia(
                query: trimmedQuery,
                mediaType: selectedType,
                source: selectedSource,
                credentials: credentials
            )
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            results = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to search"
        }
    }

    func createSelectedMedia() async throws {
        guard !isCreating else { return }

        isCreating = true
        defer { isCreating = false }

        do {
            let created = try await apiClient.createMedia(makeCreateRequest(), credentials: credentials)
            errorMessage = nil
            onMediaCreated?(created)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to create media"
            throw error
        }
    }

    private func makeCreateRequest() -> CreateMediaRequest {
        if isManualSource {
            return .manual(
                mediaType: selectedType,
                title: manualTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                imageURL: manualImageURL.nilIfBlank,
                status: manualStatus,
                progress: Int(manualProgress),
                score: Double(manualScore),
                notes: manualNotes.nilIfBlank
            )
        }

        return .provider(
            mediaType: selectedType,
            source: selectedSource,
            mediaID: selectedResult?.mediaID ?? "",
            status: nil,
            progress: defaultProgressForCreate,
            score: nil,
            notes: nil
        )
    }

    private var defaultProgressForCreate: Int? {
        switch selectedType {
        case .anime, .manga, .book, .comic, .boardgame:
            return 0
        case .all, .movie, .tv, .game:
            return nil
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

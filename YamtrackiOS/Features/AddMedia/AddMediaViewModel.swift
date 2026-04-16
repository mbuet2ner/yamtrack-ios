import Foundation
import Observation

@MainActor
@Observable
final class AddMediaViewModel {
    private let apiClient: APIClient
    private let credentials: SessionCredentials

    var selectedType: MediaType?
    var selectedSource: ProviderSource?
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
    var hasSearched = false
    var isShowingManualSheet = false
    var errorMessage: String?
    var successMessage: String?
    var onMediaCreated: ((MediaSummary) -> Void)?
    private var manualCreationRequested = false

    init(apiClient: APIClient, credentials: SessionCredentials) {
        self.apiClient = apiClient
        self.credentials = credentials
    }

    var availableTypes: [MediaType] {
        [.movie, .tv, .anime, .manga, .game, .book, .comic, .boardgame]
    }

    var availableSources: [ProviderSource] {
        guard let selectedType else { return [] }
        return ProviderSource.supportedSources(for: selectedType)
    }

    var isManualSource: Bool {
        manualCreationRequested || selectedSource == .manual
    }

    func selectType(_ type: MediaType) {
        selectedType = type
        selectedSource = ProviderSource.preferredSearchSource(for: type)
        manualCreationRequested = false
        selectedResult = nil
        results = []
        hasSearched = false
        errorMessage = nil
        successMessage = nil
        isShowingManualSheet = false
    }

    func selectSource(_ source: ProviderSource) {
        guard source != .manual else {
            manualCreationRequested = true
            isShowingManualSheet = true
            return
        }

        selectedSource = source
        manualCreationRequested = false
        selectedResult = nil
        results = []
        hasSearched = false
        errorMessage = nil
        successMessage = nil
        isShowingManualSheet = false
    }

    func reset() {
        selectedType = nil
        selectedSource = nil
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
        hasSearched = false
        isShowingManualSheet = false
        manualCreationRequested = false
        errorMessage = nil
        successMessage = nil
    }

    func search() async {
        guard let selectedType, let selectedSource, !isManualSource else { return }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            selectedResult = nil
            hasSearched = false
            return
        }

        hasSearched = true
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
        guard let selectedType, let selectedSource else { return }

        isCreating = true
        defer { isCreating = false }

        do {
            let isManualCreation = isManualSource
            let created = try await apiClient.createMedia(
                makeCreateRequest(
                    mediaType: selectedType,
                    source: selectedSource,
                    isManualCreation: isManualCreation
                ),
                credentials: credentials
            )
            errorMessage = nil
            if !isManualCreation {
                selectedResult = nil
                successMessage = "Added \(created.title)"
            }
            onMediaCreated?(created)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to create media"
            throw error
        }
    }

    private func makeCreateRequest(
        mediaType: MediaType,
        source: ProviderSource,
        isManualCreation: Bool
    ) -> CreateMediaRequest {
        if isManualCreation {
            return .manual(
                mediaType: mediaType,
                title: manualTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                imageURL: manualImageURL.nilIfBlank,
                status: manualStatus,
                progress: Int(manualProgress),
                score: Double(manualScore),
                notes: manualNotes.nilIfBlank
            )
        }

        return .provider(
            mediaType: mediaType,
            source: source,
            mediaID: selectedResult?.mediaID ?? "",
            status: nil,
            progress: defaultProgressForCreate,
            score: nil,
            notes: nil
        )
    }

    private var defaultProgressForCreate: Int? {
        guard let selectedType else { return nil }

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

import Foundation
import Observation

@MainActor
@Observable
final class AddMediaViewModel {
    enum BarcodeLookupState: Equatable {
        case idle
        case searching
        case results
        case noMatch
        case invalidISBN
    }

    private let apiClient: APIClient
    private let credentials: SessionCredentials
    private var barcodeLookupRequestID = 0

    var selectedType: MediaType = .movie {
        didSet {
            let sources = availableSources
            if !sources.contains(selectedSource) {
                selectedSource = sources.first ?? .manual
            }
            selectedResult = nil
            results = []
            invalidateBarcodeLookup()
        }
    }
    var selectedSource: ProviderSource = .tmdb {
        didSet {
            selectedResult = nil
            results = []
            invalidateBarcodeLookup()
        }
    }
    var query = ""
    var results: [AddMediaSearchResult] = []
    var selectedResult: AddMediaSearchResult?
    var scannedISBN: String?
    var barcodeLookupState: BarcodeLookupState = .idle
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
        invalidateBarcodeLookup()
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

    func lookupBookBarcode(_ rawBarcode: String) async {
        guard selectedType == .book else { return }

        guard let isbn = ISBN.normalize(rawBarcode) else {
            scannedISBN = nil
            results = []
            selectedResult = nil
            barcodeLookupState = .invalidISBN
            errorMessage = "That barcode does not look like a valid ISBN."
            return
        }

        let requestID = beginBarcodeLookup(with: isbn)
        scannedISBN = isbn
        barcodeLookupState = .searching
        isSearching = true
        defer { isSearching = false }

        do {
            if let results = try await lookupBarcodeResults(
                query: isbn,
                source: .openlibrary,
                requestID: requestID
            ) {
                applyBarcodeLookupResults(results)
                errorMessage = nil
                return
            }

            guard isBarcodeLookupRequestActive(requestID) else { return }

            if let results = try await lookupBarcodeResults(
                query: isbn,
                source: .hardcover,
                requestID: requestID
            ) {
                applyBarcodeLookupResults(results)
            } else if isBarcodeLookupRequestActive(requestID) {
                results = []
                selectedResult = nil
                barcodeLookupState = .noMatch
            }
            if isBarcodeLookupRequestActive(requestID) {
                errorMessage = nil
            }
        } catch is CancellationError {
        } catch {
            guard isBarcodeLookupRequestActive(requestID) else { return }
            results = []
            selectedResult = nil
            barcodeLookupState = .idle
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to search"
        }
    }

    func moveScannedISBNToSearchField() {
        query = scannedISBN ?? ""
        scannedISBN = nil
        results = []
        selectedResult = nil
        barcodeLookupState = .idle
        errorMessage = nil
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

    private func applyBarcodeLookupResults(_ lookupResults: [AddMediaSearchResult]) {
        results = lookupResults
        selectedResult = lookupResults.count == 1 ? lookupResults.first : nil
        barcodeLookupState = .results
    }

    private func lookupBarcodeResults(
        query: String,
        source: ProviderSource,
        requestID: Int
    ) async throws -> [AddMediaSearchResult]? {
        do {
            let searchResults = try await apiClient.searchMedia(
                query: query,
                mediaType: .book,
                source: source,
                credentials: credentials
            )
            guard isBarcodeLookupRequestActive(requestID) else { return nil }
            return searchResults.isEmpty ? nil : searchResults
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard source == .openlibrary else { throw error }
            guard isBarcodeLookupRequestActive(requestID) else { return nil }
            return nil
        }
    }

    private func beginBarcodeLookup(with isbn: String) -> Int {
        barcodeLookupRequestID += 1
        barcodeLookupState = .searching
        scannedISBN = isbn
        return barcodeLookupRequestID
    }

    private func invalidateBarcodeLookup() {
        barcodeLookupRequestID += 1
        scannedISBN = nil
        barcodeLookupState = .idle
    }

    private func isBarcodeLookupRequestActive(_ requestID: Int) -> Bool {
        barcodeLookupRequestID == requestID
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

        let providerSource = selectedResult
            .flatMap { ProviderSource(rawValue: $0.source) } ?? selectedSource

        return .provider(
            mediaType: selectedType,
            source: providerSource,
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

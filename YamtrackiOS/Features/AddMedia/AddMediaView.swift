import SwiftUI

struct AddMediaView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddMediaViewModel
    var showsCloseButton = true
    @State private var isShowingBookBarcodeScanner = false
    @State private var didTriggerUITestBarcodeLookup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introSection
                typeSection

                if viewModel.selectedType != nil {
                    searchComposer

                    if let errorMessage = viewModel.errorMessage {
                        errorCard(errorMessage)
                    }

                    if viewModel.hasSearched {
                        resultsSection
                    }
                }

                if viewModel.selectedType == .book && viewModel.barcodeLookupState == .noMatch {
                    barcodeNoMatchSection
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 132)
        }
        .scrollIndicators(.hidden)
        .background(addMediaBackground)
        .navigationTitle("Add Media")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .sheet(isPresented: manualSheetBinding) {
            AddMediaManualEntrySheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isShowingBookBarcodeScanner) {
            NavigationStack {
                BookBarcodeScannerView { scannedValue in
                    Task {
                        await viewModel.lookupBookBarcode(scannedValue)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: viewModel.selectedType) { _, newValue in
            if newValue != .book {
                isShowingBookBarcodeScanner = false
                didTriggerUITestBarcodeLookup = false
            } else {
                triggerUITestBarcodeLookupIfNeeded()
            }
        }
        .onAppear {
            triggerUITestBarcodeLookupIfNeeded()
        }
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add something new")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text(introCopy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a type")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.availableTypes) { type in
                        selectionChip(
                            title: type.singularTitle,
                            systemImage: type.systemImage,
                            isSelected: viewModel.selectedType == type,
                            accessibilityIdentifier: "add-media-type-\(type.rawValue)"
                        ) {
                            viewModel.selectType(type)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var searchComposer: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(searchComposerTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(searchComposerSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    providerMenu
                }

                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Search title", text: $viewModel.query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .accessibilityIdentifier("add-media-search-field")
                            .onSubmit {
                                performSearch()
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Button {
                        performSearch()
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isSearching {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.forward.circle.fill")
                            }

                            Text(viewModel.isSearching ? "Searching" : "Search")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("add-media-search-button")
                    .disabled(!canSearch)
                }

                if viewModel.selectedType == .book {
                    Button {
                        isShowingBookBarcodeScanner = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "barcode.viewfinder")
                            Text("Scan Book Barcode")
                                .fontWeight(.semibold)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("add-media-scan-book-barcode-button")
                }

                if !viewModel.hasSearched {
                    Text("Results stay hidden until you run a search.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var providerMenu: some View {
        let selectedSource = viewModel.selectedSource ?? searchProviders.first ?? .manual

        return Menu {
            ForEach(searchProviders) { source in
                Button {
                    viewModel.selectSource(source)
                } label: {
                    Label(source.title, systemImage: source.systemImage)
                }
                .accessibilityIdentifier("add-media-provider-\(source.rawValue)")
            }

            Divider()

            Button {
                viewModel.selectSource(.manual)
            } label: {
                Label("Manual Entry", systemImage: ProviderSource.manual.systemImage)
            }
            .accessibilityIdentifier("add-media-provider-manual")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedSource.systemImage)
                    .font(.caption.weight(.semibold))
                Text(selectedSource.title)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.4))
            )
        }
        .accessibilityIdentifier("add-media-provider-menu")
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Results")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let resultsSubtitle {
                    Text(resultsSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.results.isEmpty {
                emptyResultsCard
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.results) { result in
                        resultCard(result)
                    }
                }
            }
        }
    }

    private func resultCard(_ result: AddMediaSearchResult) -> some View {
        Button {
            viewModel.selectedResult = result
            viewModel.successMessage = nil
        } label: {
            HStack(alignment: .top, spacing: 14) {
                resultPoster(imageURL: result.image, mediaType: result.mediaType)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)

                        HStack(spacing: 8) {
                            badge(
                                title: MediaType(rawValue: result.mediaType)?.singularTitle ?? result.mediaType.capitalized,
                                systemImage: MediaType(rawValue: result.mediaType)?.systemImage ?? "square.stack.fill"
                            )
                            badge(
                                title: ProviderSource(rawValue: result.source)?.title ?? result.source.uppercased(),
                                systemImage: ProviderSource(rawValue: result.source)?.systemImage ?? "globe"
                            )
                        }
                    }

                    Spacer(minLength: 0)

                    HStack {
                        if result.tracked {
                            Text("Already tracked")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(viewModel.selectedResult?.id == result.id ? "Selected" : "Tap to select")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(viewModel.selectedResult?.id == result.id ? Color.accentColor : Color.secondary)
                        }

                        Spacer()

                        Image(systemName: resultIndicator(for: result))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(result.tracked ? Color.secondary : (viewModel.selectedResult?.id == result.id ? Color.accentColor : Color.secondary.opacity(0.45)))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(resultBackground(isSelected: viewModel.selectedResult?.id == result.id))
        }
        .buttonStyle(.plain)
        .disabled(result.tracked)
        .accessibilityIdentifier("add-media-result-\(result.id)")
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.10))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.red.opacity(0.18))
        }
    }

    private var barcodeNoMatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No barcode match found.")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Use the scanned ISBN in the search field to try a title search instead.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Use ISBN in Search") {
                viewModel.moveScannedISBNToSearchField()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("add-media-barcode-fallback-button")
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.12)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bottomActionTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("add-media-bottom-title")

                    Text(bottomActionSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("add-media-bottom-subtitle")
                }

                Spacer(minLength: 0)

                Button {
                    Task {
                        do {
                            try await viewModel.createSelectedMedia()
                        } catch {
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isCreating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }

                        Text("Add")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("add-media-submit-button")
                .disabled(createDisabled)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
        }
    }

    private var emptyResultsCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("No matches yet")
                .font(.headline)

            Text("Try a broader title, a different spelling, or another provider.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.32))
        )
    }

    private var addMediaBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(red: 0.97, green: 0.94, blue: 0.89),
                Color(red: 0.89, green: 0.93, blue: 0.96).opacity(0.72),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var fieldBackground: some ShapeStyle {
        .regularMaterial
    }

    private var introCopy: String {
        if let successMessage = viewModel.successMessage {
            return "\(successMessage). Search again or switch types to keep adding."
        }

        if let selectedType = viewModel.selectedType {
            if selectedType == .book {
                return "Search for a book, switch providers, or scan a barcode to jump straight to the right result."
            }

            return "Search for a \(selectedType.singularTitle.lowercased()) from a provider or jump to manual entry from the menu."
        }

        return "Pick a media type first. The search composer appears after that."
    }

    private var searchComposerTitle: String {
        guard let selectedType = viewModel.selectedType else {
            return "Search"
        }

        return "Search \(selectedType.singularTitle)"
    }

    private var searchComposerSubtitle: String {
        let selectedSource = viewModel.selectedSource ?? searchProviders.first ?? .manual
        return "Using \(selectedSource.title). Switch providers or choose Manual Entry from the menu."
    }

    private var resultsSubtitle: String? {
        guard !viewModel.results.isEmpty else { return nil }
        let selectedSource = viewModel.selectedSource ?? searchProviders.first ?? .manual
        return "\(viewModel.results.count) result\(viewModel.results.count == 1 ? "" : "s") from \(selectedSource.title)."
    }

    private var bottomActionTitle: String {
        if let successMessage = viewModel.successMessage, viewModel.selectedResult == nil {
            return successMessage
        }

        guard let selectedType = viewModel.selectedType else {
            return "Choose A Type"
        }

        if viewModel.selectedResult != nil {
            return "Add \(selectedType.singularTitle)"
        }

        if viewModel.hasSearched {
            return viewModel.results.isEmpty ? "No Match Yet" : "Select A Result"
        }

        return "Search \(selectedType.singularTitle)"
    }

    private var bottomActionSubtitle: String {
        if let successMessage = viewModel.successMessage, viewModel.selectedResult == nil {
            return successMessage
        }

        guard let selectedType = viewModel.selectedType else {
            return "Pick a media type to unlock search."
        }

        if let selectedResult = viewModel.selectedResult {
            return selectedResult.title
        }

        if viewModel.hasSearched {
            if viewModel.results.isEmpty {
                return "Try another title or switch providers from the menu."
            }

            return "Choose one \(selectedType.singularTitle.lowercased()) from the results list."
        }

        return "The default provider is ready. Run a search when you are."
    }

    private var searchProviders: [ProviderSource] {
        viewModel.availableSources.filter { $0 != .manual }
    }

    private var canSearch: Bool {
        !viewModel.isSearching && !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var createDisabled: Bool {
        if viewModel.isCreating {
            return true
        }

        return viewModel.selectedResult == nil || viewModel.selectedResult?.tracked == true
    }

    private var manualSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isShowingManualSheet },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissManualSheet()
                }
            }
        )
    }

    private func selectionChip(
        title: String,
        systemImage: String,
        isSelected: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.white.opacity(0.42)))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func badge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.4))
            )
    }

    private func resultBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.white.opacity(0.34))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.16))
            }
    }

    private func resultIndicator(for result: AddMediaSearchResult) -> String {
        if result.tracked {
            return "checkmark.circle"
        }

        return viewModel.selectedResult?.id == result.id ? "checkmark.circle.fill" : "circle"
    }

    private func resultPoster(imageURL: String?, mediaType: String, width: CGFloat = 76, height: CGFloat = 112) -> some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        posterPlaceholder(mediaType: mediaType)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        posterPlaceholder(mediaType: mediaType)
                    @unknown default:
                        posterPlaceholder(mediaType: mediaType)
                    }
                }
            } else {
                posterPlaceholder(mediaType: mediaType)
            }
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.tertiarySystemBackground),
                            Color(.secondarySystemBackground).opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.18))
        }
    }

    private func posterPlaceholder(mediaType: String) -> some View {
        let resolvedType = MediaType(rawValue: mediaType)

        return ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.88, blue: 0.81),
                    Color(red: 0.81, green: 0.86, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: resolvedType?.systemImage ?? "square.stack.3d.up.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(resolvedType?.singularTitle ?? "Media")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func performSearch() {
        guard canSearch else { return }
        viewModel.successMessage = nil
        Task {
            await viewModel.search()
        }
    }

    private func triggerUITestBarcodeLookupIfNeeded() {
        guard !didTriggerUITestBarcodeLookup else { return }
        guard viewModel.selectedType == .book else { return }
        guard let simulatedISBN = ProcessInfo.processInfo.value(after: "-ui-testing-simulated-book-isbn") else {
            return
        }

        didTriggerUITestBarcodeLookup = true
        Task {
            await viewModel.lookupBookBarcode(simulatedISBN)
        }
    }
}

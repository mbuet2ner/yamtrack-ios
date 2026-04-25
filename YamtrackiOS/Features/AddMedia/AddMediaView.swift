import SwiftUI

struct AddMediaView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddMediaViewModel
    var showsCloseButton = true
    @State private var isShowingBookBarcodeScanner = false
    @State private var didTriggerUITestBarcodeLookup = false
    @State private var pendingAddResult: AddMediaSearchResult?
    private var searchChromePresentation: AddMediaSearchChromePresentation {
        AddMediaSearchChromePresentation(selectedType: viewModel.selectedType)
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.selectedType == nil {
                        introSection
                    }

                    if viewModel.selectedType != nil {
                        if let successMessage = viewModel.successMessage {
                            successBanner(successMessage)
                        }

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
                .padding(.top, searchChromePresentation.contentTopSpacing)
                .padding(.bottom, 36)
            }
        }
        .scrollIndicators(.hidden)
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .top, spacing: 0) {
            floatingHeader
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
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
        .alert("Add To Library?", isPresented: pendingAddBinding, presenting: pendingAddResult) { result in
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                confirmAdd(result)
            }
        } message: { result in
            Text(result.title)
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
    }

    private var floatingHeader: some View {
        AddMediaFloatingHeader(
            viewModel: viewModel,
            showsCloseButton: showsCloseButton,
            presentation: searchChromePresentation,
            searchProviders: searchProviders,
            canSearch: canSearch,
            searchActionTint: searchActionTint,
            onClose: { dismiss() },
            onScanBarcode: { isShowingBookBarcodeScanner = true },
            onSearch: performSearch
        )
    }

    private var resultRows: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.results) { result in
                AddMediaResultRow(
                    result: result,
                    isCreating: viewModel.isCreating
                ) {
                    pendingAddResult = result
                    viewModel.successMessage = nil
                }
            }
        }
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a type")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Start with the kind of media you want to bring into your library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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
                resultRows
            }
        }
    }

    private func successBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.green.opacity(0.10))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.green.opacity(0.16))
        }
        .accessibilityIdentifier("add-media-success-message")
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
                .fill(Color.red.opacity(0.08))
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
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("add-media-barcode-fallback-button")
        }
    }

    private var emptyResultsCard: some View {
        ContentSurface {
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
            .frame(maxWidth: .infinity)
        }
    }

    private var searchActionTint: Color {
        guard canSearch else { return Color.clear }
        return Color.accentColor.opacity(0.16)
    }

    private var resultsSubtitle: String? {
        guard !viewModel.results.isEmpty else { return nil }
        let selectedSource = viewModel.selectedSource ?? searchProviders.first ?? .manual
        return "\(viewModel.results.count) result\(viewModel.results.count == 1 ? "" : "s") from \(selectedSource.title)."
    }

    private var searchProviders: [ProviderSource] {
        viewModel.availableSources.filter { $0 != .manual }
    }

    private var canSearch: Bool {
        !viewModel.isSearching && !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private var pendingAddBinding: Binding<Bool> {
        Binding(
            get: { pendingAddResult != nil },
            set: { isPresented in
                if !isPresented {
                    pendingAddResult = nil
                }
            }
        )
    }

    private func performSearch() {
        guard canSearch else { return }
        viewModel.successMessage = nil
        Task {
            await viewModel.search()
        }
    }

    private func confirmAdd(_ result: AddMediaSearchResult) {
        Task {
            do {
                try await viewModel.createMedia(for: result)
                pendingAddResult = nil
            } catch {
            }
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

private struct AddMediaFloatingHeader: View {
    @Bindable var viewModel: AddMediaViewModel
    let showsCloseButton: Bool
    let presentation: AddMediaSearchChromePresentation
    let searchProviders: [ProviderSource]
    let canSearch: Bool
    let searchActionTint: Color
    let onClose: () -> Void
    let onScanBarcode: () -> Void
    let onSearch: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            titleRow
            typePickerRow

            if viewModel.selectedType != nil {
                AddMediaSearchComposer(
                    viewModel: viewModel,
                    presentation: presentation,
                    searchProviders: searchProviders,
                    canSearch: canSearch,
                    searchActionTint: searchActionTint,
                    onScanBarcode: onScanBarcode,
                    onSearch: onSearch
                )
                .padding(.horizontal, Theme.screenPadding)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, presentation.chromeBottomPadding)
        .background {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemGroupedBackground).opacity(0.96),
                    Color(uiColor: .systemGroupedBackground).opacity(0.72),
                    Color(uiColor: .systemGroupedBackground).opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private var titleRow: some View {
        ZStack {
            Text("Add Media")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            HStack {
                if showsCloseButton {
                    Button("Close", action: onClose)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)
                        .buttonStyle(.glass)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Theme.screenPadding)
    }

    private var typePickerRow: some View {
        GlassEffectContainer(spacing: 10) {
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
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 4)
            }
        }
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
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .frame(height: 48)
            .padding(.horizontal, 18)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(Color.accentColor.opacity(0.18)).interactive() : .regular.interactive(),
            in: .capsule
        )
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct AddMediaSearchComposer: View {
    @Bindable var viewModel: AddMediaViewModel
    let presentation: AddMediaSearchChromePresentation
    let searchProviders: [ProviderSource]
    let canSearch: Bool
    let searchActionTint: Color
    let onScanBarcode: () -> Void
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField

            GlassEffectContainer(spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    providerMenu

                    if presentation.showsScannerShortcut {
                        Button(action: onScanBarcode) {
                            Label("Scan", systemImage: "barcode.viewfinder")
                                .font(.subheadline.weight(.semibold))
                                .frame(height: presentation.controlHeight)
                        }
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("add-media-scan-book-barcode-button")
                    }

                    Spacer(minLength: 0)

                    Button(action: onSearch) {
                        Group {
                            if viewModel.isSearching {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.headline.weight(.semibold))
                            }
                        }
                        .frame(
                            width: presentation.searchActionDiameter,
                            height: presentation.searchActionDiameter
                        )
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(searchActionTint).interactive(), in: .circle)
                    .accessibilityIdentifier("add-media-search-button")
                    .accessibilityLabel(viewModel.isSearching ? "Searching" : "Search")
                    .disabled(!canSearch)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("Search title", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .font(.title3.weight(.medium))
                .accessibilityIdentifier("add-media-search-field")
                .onSubmit(performSearch)
        }
        .padding(.horizontal, 20)
        .frame(height: presentation.searchFieldHeight)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
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
            .frame(height: presentation.controlHeight)
            .padding(.horizontal, 18)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .accessibilityIdentifier("add-media-provider-menu")
    }

    private func performSearch() {
        onSearch()
    }
}

private struct AddMediaResultRow: View {
    let result: AddMediaSearchResult
    let isCreating: Bool
    let onAdd: () -> Void

    var body: some View {
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

                if result.tracked {
                    Text("Tracked")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            resultActionButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(resultBackground(isTracked: result.tracked))
        .accessibilityElement(children: .contain)
    }

    private var resultActionButton: some View {
        Button(action: onAdd) {
            Image(systemName: result.tracked ? "checkmark" : "plus")
                .font(.headline.weight(.semibold))
                .foregroundStyle(result.tracked ? Color.secondary : Color.accentColor)
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .glassEffect(
            result.tracked ? .regular : .regular.tint(Color.accentColor.opacity(0.18)).interactive(),
            in: .circle
        )
        .disabled(result.tracked || isCreating)
        .accessibilityIdentifier("add-media-result-add-\(result.id)")
        .accessibilityLabel(result.tracked ? "\(result.title) already tracked" : "Add \(result.title)")
    }

    private func badge(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
    }

    private func resultBackground(isTracked: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(uiColor: isTracked ? .tertiarySystemGroupedBackground : .secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isTracked ? 0.04 : 0.06))
            }
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
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private func posterPlaceholder(mediaType: String) -> some View {
        let resolvedType = MediaType(rawValue: mediaType)

        return ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .tertiarySystemGroupedBackground),
                    Color(uiColor: .secondarySystemGroupedBackground)
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
}

struct AddMediaSearchChromePresentation: Equatable {
    let usesDetachedSearchAction: Bool
    let showsScannerShortcut: Bool
    let searchFieldHeight: CGFloat
    let controlHeight: CGFloat
    let searchActionDiameter: CGFloat
    let contentTopSpacing: CGFloat
    let chromeBottomPadding: CGFloat

    init(selectedType: MediaType?) {
        usesDetachedSearchAction = true
        showsScannerShortcut = selectedType == .book
        searchFieldHeight = 64
        controlHeight = 56
        searchActionDiameter = 64
        contentTopSpacing = selectedType == nil ? 16 : 20
        chromeBottomPadding = selectedType == nil ? 12 : 16
    }
}

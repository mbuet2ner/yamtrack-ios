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
                    introSection

                    if viewModel.selectedType != nil {
                        if let successMessage = viewModel.successMessage {
                            successBanner(successMessage)
                        }

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
                .padding(.top, showsCloseButton ? 144 : 108)
                .padding(.bottom, 36)
            }
        }
        .scrollIndicators(.hidden)
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
        .overlay(alignment: .top) {
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
        VStack(spacing: 22) {
            HStack {
                if showsCloseButton {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }

                Spacer(minLength: 0)

                Text("Add Media")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if showsCloseButton {
                    Color.clear
                        .frame(width: 92, height: 46)
                }
            }

            typePickerRow
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 10)
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

    private var typePickerRow: some View {
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

    private var searchComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search title", text: $viewModel.query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .font(.title3)
                    .accessibilityIdentifier("add-media-search-field")
                    .onSubmit {
                        performSearch()
                    }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            }

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    providerMenu

                    if searchChromePresentation.showsScannerShortcut {
                        Button {
                            isShowingBookBarcodeScanner = true
                        } label: {
                            Label("Scan", systemImage: "barcode.viewfinder")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("add-media-scan-book-barcode-button")
                    }

                    Spacer(minLength: 0)

                    Button {
                        performSearch()
                    } label: {
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
                            width: searchChromePresentation.searchActionDiameter,
                            height: searchChromePresentation.searchActionDiameter
                        )
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(Color.accentColor.opacity(0.16)).interactive(), in: .circle)
                    .accessibilityIdentifier("add-media-search-button")
                    .accessibilityLabel(viewModel.isSearching ? "Searching" : "Search")
                    .disabled(!canSearch)
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
            .glassEffect(.regular.interactive(), in: .capsule)
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

            resultActionButton(for: result)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(resultBackground(isTracked: result.tracked))
        .accessibilityElement(children: .contain)
    }

    private func resultActionButton(for result: AddMediaSearchResult) -> some View {
        Button {
            pendingAddResult = result
            viewModel.successMessage = nil
        } label: {
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
        .disabled(result.tracked || viewModel.isCreating)
        .accessibilityIdentifier("add-media-result-add-\(result.id)")
        .accessibilityLabel(result.tracked ? "\(result.title) already tracked" : "Add \(result.title)")
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

    private var fieldBackground: some ShapeStyle {
        Color(uiColor: .secondarySystemGroupedBackground)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(Color.accentColor.opacity(0.18)).interactive() : .regular.interactive(),
            in: .capsule
        )
        .accessibilityIdentifier(accessibilityIdentifier)
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

struct AddMediaSearchChromePresentation: Equatable {
    let usesDetachedSearchAction: Bool
    let showsScannerShortcut: Bool
    let searchActionDiameter: CGFloat

    init(selectedType: MediaType?) {
        usesDetachedSearchAction = true
        showsScannerShortcut = selectedType == .book
        searchActionDiameter = 52
    }
}

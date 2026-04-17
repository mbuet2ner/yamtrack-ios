import SwiftUI

struct AddMediaView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddMediaViewModel
    var showsCloseButton = true
    @State private var isShowingBookBarcodeScanner = false
    @State private var didTriggerUITestBarcodeLookup = false
    @State private var pendingAddResult: AddMediaSearchResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                typeSection

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
            .padding(.top, showsCloseButton ? 20 : 12)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .background(addMediaBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(showsCloseButton ? .automatic : .hidden, for: .navigationBar)
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
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    providerMenu

                    Spacer(minLength: 0)

                    if viewModel.selectedType == .book {
                        Button {
                            isShowingBookBarcodeScanner = true
                        } label: {
                            Label("Scan", systemImage: "barcode.viewfinder")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("add-media-scan-book-barcode-button")
                    }
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
                .foregroundStyle(result.tracked ? Color.secondary : Color.white)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(result.tracked ? Color.white.opacity(0.34) : Color.accentColor)
                )
        }
        .buttonStyle(.plain)
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
                .fill(Color.green.opacity(0.12))
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

    private func resultBackground(isTracked: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(isTracked ? Color.white.opacity(0.26) : Color.white.opacity(0.34))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isTracked ? Color.white.opacity(0.12) : Color.white.opacity(0.16))
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

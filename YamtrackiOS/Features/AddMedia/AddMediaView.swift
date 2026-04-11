import SwiftUI

struct AddMediaView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddMediaViewModel
    var showsCloseButton = true
    var onMediaCreated: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard
                typeSection
                sourceSection

                if viewModel.isManualSource {
                    manualSection
                } else {
                    searchSection
                    if let selectedResult = viewModel.selectedResult {
                        selectedResultCard(selectedResult)
                    }
                    resultsSection
                }

                if let errorMessage = viewModel.errorMessage {
                    errorCard(errorMessage)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 14)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(addMediaBackground)
        .navigationTitle("Add Media")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
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

    private var heroCard: some View {
        GlassSurface {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.90, blue: 0.78),
                                    Color(red: 0.86, green: 0.92, blue: 0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: viewModel.selectedType.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Build your library")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(heroSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var typeSection: some View {
        sectionContainer(title: "Media Type", subtitle: "Choose what you want to add.") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.availableTypes) { type in
                        selectionChip(
                            title: type.singularTitle,
                            systemImage: type.systemImage,
                            isSelected: viewModel.selectedType == type
                        ) {
                            viewModel.selectedType = type
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var sourceSection: some View {
        sectionContainer(title: "Source", subtitle: "Pick a provider or add it manually.") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.availableSources) { source in
                        selectionChip(
                            title: source.title,
                            systemImage: source.systemImage,
                            isSelected: viewModel.selectedSource == source
                        ) {
                            viewModel.selectedSource = source
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var manualSection: some View {
        sectionContainer(title: "Manual Entry", subtitle: "Create a custom \(viewModel.selectedType.singularTitle.lowercased()) with your own details.") {
            VStack(spacing: 12) {
                textFieldRow(title: "Title", prompt: "Enter a title", text: $viewModel.manualTitle)

                textFieldRow(title: "Image URL", prompt: "https://…", text: $viewModel.manualImageURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Status", selection: $viewModel.manualStatus) {
                        ForEach(MediaSummary.Status.allCases, id: \.self) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                HStack(spacing: 12) {
                    textFieldRow(title: "Progress", prompt: "0", text: $viewModel.manualProgress)
                        .keyboardType(.numberPad)

                    textFieldRow(title: "Score", prompt: "Optional", text: $viewModel.manualScore)
                        .keyboardType(.decimalPad)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("Add context or thoughts", text: $viewModel.manualNotes, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(fieldBackground)
                }
            }
        }
    }

    private var searchSection: some View {
        sectionContainer(title: "Search", subtitle: "Look up a \(viewModel.selectedType.singularTitle.lowercased()) from \(viewModel.selectedSource.title).") {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search title", text: $viewModel.query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit {
                            guard canSearch else { return }
                            Task { await viewModel.search() }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(fieldBackground)

                Button {
                    Task { await viewModel.search() }
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
                .disabled(!canSearch)
            }
        }
    }

    private var resultsSection: some View {
        sectionContainer(title: "Results", subtitle: resultsSubtitle) {
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
    }

    private func selectedResultCard(_ result: AddMediaSearchResult) -> some View {
        sectionContainer(title: "Ready To Add", subtitle: "This is the item that will be added when you continue.") {
            HStack(spacing: 14) {
                resultPoster(imageURL: result.image, mediaType: result.mediaType, width: 88, height: 128)

                VStack(alignment: .leading, spacing: 8) {
                    Text(result.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text((ProviderSource(rawValue: result.source)?.title ?? result.source.uppercased()) + " • " + (MediaType(rawValue: result.mediaType)?.singularTitle ?? result.mediaType.capitalized))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label("Selected", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .padding(.top, 4)
                }

                Spacer()
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        GlassSurface {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
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

                    Text(bottomActionSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Button {
                    Task {
                        do {
                            try await viewModel.createSelectedMedia()
                            onMediaCreated?()
                            if showsCloseButton {
                                dismiss()
                            }
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
                        Text(viewModel.isManualSource ? "Create" : "Add")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(createDisabled)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
        }
    }

    private var emptyResultsCard: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.35))
            .overlay {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.55))

                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 56, height: 56)

                    VStack(spacing: 6) {
                        Text(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Search for something to add." : "No matches yet")
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        Text(viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Results with artwork and provider metadata will show up here." : "Try a broader title, a different spelling, or another provider.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
            }
            .frame(maxWidth: .infinity)
    }

    private var addMediaBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(red: 0.96, green: 0.93, blue: 0.89),
                Color(red: 0.88, green: 0.93, blue: 0.96).opacity(0.7),
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

    private var heroSubtitle: String {
        if viewModel.isManualSource {
            return "Create a custom \(viewModel.selectedType.singularTitle.lowercased()) entry with your own metadata."
        }

        return "Search \(viewModel.selectedSource.title) for a \(viewModel.selectedType.singularTitle.lowercased()) and add it with one tap."
    }

    private var resultsSubtitle: String {
        if viewModel.results.isEmpty {
            return "Artwork, provider, and selection state appear here."
        }

        return "\(viewModel.results.count) result\(viewModel.results.count == 1 ? "" : "s") from \(viewModel.selectedSource.title)."
    }

    private var bottomActionTitle: String {
        if viewModel.isManualSource {
            return "Create \(viewModel.selectedType.singularTitle)"
        }

        return viewModel.selectedResult == nil ? "Select A Result" : "Add \(viewModel.selectedType.singularTitle)"
    }

    private var bottomActionSubtitle: String {
        if viewModel.isManualSource {
            return "Manual entries land directly in your library."
        }

        if let selectedResult = viewModel.selectedResult {
            return selectedResult.title
        }

        return "Choose a result with artwork and metadata first."
    }

    private var canSearch: Bool {
        !viewModel.isSearching && !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var createDisabled: Bool {
        if viewModel.isCreating {
            return true
        }

        if viewModel.isManualSource {
            return viewModel.manualTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return viewModel.selectedResult == nil || viewModel.selectedResult?.tracked == true
    }

    private func sectionContainer<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                content()
            }
        }
    }

    private func selectionChip(
        title: String,
        systemImage: String,
        isSelected: Bool,
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
                    .fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.white.opacity(0.4)))
            )
        }
        .buttonStyle(.plain)
    }

    private func textFieldRow(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: text)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(fieldBackground)
        }
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
                Image(systemName: resolvedType?.systemImage ?? "square.stack.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(resolvedType?.singularTitle ?? mediaType.capitalized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
        }
    }
}

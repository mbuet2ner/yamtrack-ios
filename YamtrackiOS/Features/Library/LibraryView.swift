import SwiftUI

struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    let baseURLString: String
    let sessionWarningMessage: String?
    let onOpenAdd: () -> Void
    let onOpenConnectionSettings: () -> Void
    @State private var trackingEditor: LibraryTrackingEditorState?
    @State private var searchText = ""
    @State private var selectedIndexLetter = ""

    var body: some View {
        let presentation = LibraryPresentation(
            items: viewModel.items,
            allItems: viewModel.allItems,
            selectedFilter: viewModel.selectedFilter,
            searchText: searchText
        )

        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleSection(presentation: presentation)

                    if let errorMessage = viewModel.errorMessage, !viewModel.items.isEmpty {
                        inlineErrorBanner(message: errorMessage)
                    }

                    if let sessionWarningMessage, !sessionWarningMessage.isEmpty {
                        sessionWarningBanner(message: sessionWarningMessage)
                    }

                    if viewModel.items.isEmpty, !viewModel.isLoading {
                        emptyLibraryContent(presentation: presentation)
                    } else if presentation.sections.isEmpty {
                        noSearchResultsCard
                    } else {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(presentation.sections) { section in
                                LibrarySectionView(
                                    section: section,
                                    makeDetailViewModel: viewModel.makeDetailViewModel(for:),
                                    onEdit: { item, detailViewModel in
                                        trackingEditor = LibraryTrackingEditorState(
                                            id: item.id,
                                            item: item,
                                            viewModel: detailViewModel
                                        )
                                    }
                                )
                                    .id(section.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) {
                LibraryChrome(
                    baseURLString: baseURLString,
                    selectedFilter: $viewModel.selectedFilter,
                    onOpenConnectionSettings: onOpenConnectionSettings
                )
            }
            .overlay(alignment: .trailing) {
                if !presentation.indexLetters.isEmpty {
                    AlphabetIndexRail(
                        letters: presentation.alphabetIndexLetters,
                        enabledLetters: Set(presentation.indexLetters),
                        selectedLetter: selectedIndexLetter
                    ) { letter in
                        guard presentation.indexLetters.contains(letter) else { return }
                        selectedIndexLetter = letter
                        withAnimation(.smooth(duration: 0.22)) {
                            scrollProxy.scrollTo(letter, anchor: .top)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomChrome
            }
            .overlay {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                }
            }
            .sensoryFeedback(.selection, trigger: selectedIndexLetter)
            .refreshable {
                await viewModel.load()
            }
            .sheet(item: $trackingEditor) { editor in
                TrackingEditorSheet(
                    viewModel: editor.viewModel,
                    status: editor.item.status,
                    progress: editor.item.progress,
                    score: editor.item.score,
                    notes: editor.item.notes
                )
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
    }

    private var bottomChrome: some View {
        BottomChrome {
            Spacer(minLength: 0)

            FloatingAddOrb {
                onOpenAdd()
            }
        }
    }

    private func titleSection(presentation: LibraryPresentation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Library")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                Text("\(viewModel.items.count) tracked")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.items.isEmpty {
                GlassEffectContainer(spacing: 9) {
                    HStack(spacing: 9) {
                        libraryMetricChip(
                            title: "\(presentation.completedCount)",
                            subtitle: "Done",
                            systemImage: "checkmark.circle.fill",
                            tint: .green
                        )
                        libraryMetricChip(
                            title: "\(presentation.ratedCount)",
                            subtitle: "Rated",
                            systemImage: "star.fill",
                            tint: .orange
                        )
                    }
                }
            }

            librarySearchField
        }
    }

    private var librarySearchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.headline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("Search library", text: $searchText)
                .font(.headline.weight(.medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            Capsule(style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var noSearchResultsCard: some View {
        ContentSurface {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("No Matches")
                    .font(.headline.weight(.semibold))

                Text("Try a different title or clear the search.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func emptyLibraryContent(presentation: LibraryPresentation) -> some View {
        if let errorMessage = viewModel.errorMessage {
            libraryStateCard(
                title: viewModel.isAuthenticationError ? "Session Expired" : "Library Error",
                systemImage: viewModel.isAuthenticationError ? "person.crop.circle.badge.exclamationmark" : "wifi.exclamationmark",
                description: viewModel.isAuthenticationError ? "Your Yamtrack session is no longer valid. Open connection settings to reconnect." : errorMessage
            ) {
                if viewModel.isAuthenticationError {
                    Button("Open Connection Settings") {
                        onOpenConnectionSettings()
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button("Try Again") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        } else {
            libraryStateCard(
                title: presentation.emptyLibraryTitle,
                systemImage: presentation.emptyLibrarySystemImage,
                description: presentation.emptyLibraryDescription
            ) {
                Button("Add Media") {
                    onOpenAdd()
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private func inlineErrorBanner(message: String) -> some View {
        compactBanner(message: message, systemImage: "exclamationmark.triangle.fill", tint: .red)
    }

    private func sessionWarningBanner(message: String) -> some View {
        compactBanner(message: message, systemImage: "exclamationmark.shield.fill", tint: .orange)
    }

    private func compactBanner(message: String, systemImage: String, tint: Color) -> some View {
        Label(message, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(tint.opacity(0.07)), in: .rect(cornerRadius: 22))
    }

    private func libraryMetricChip(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)

            Text("\(title) \(subtitle)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule(style: .continuous).fill(Color(uiColor: .secondarySystemGroupedBackground)))
    }

    @ViewBuilder
    private func libraryStateCard<Actions: View>(
        title: String,
        systemImage: String,
        description: String,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) -> some View {
        VStack {
            ContentSurface {
                VStack(spacing: 16) {
                    Image(systemName: systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 6) {
                        Text(title)
                            .font(.title3.weight(.semibold))

                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    actions()
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, Theme.screenPadding)
        }
    }
}

private struct LibraryTrackingEditorState: Identifiable {
    let id: Int
    let item: MediaSummary
    let viewModel: MediaDetailViewModel
}

struct LibraryPresentation: Equatable {
    let sections: [LibrarySection]
    let indexLetters: [String]
    let alphabetIndexLetters: [String]
    let completedCount: Int
    let ratedCount: Int
    let emptyLibraryTitle: String
    let emptyLibrarySystemImage: String
    let emptyLibraryDescription: String

    init(
        items: [MediaSummary],
        allItems: [MediaSummary],
        selectedFilter: MediaType,
        searchText: String
    ) {
        completedCount = items.filter { $0.status == .completed }.count
        ratedCount = items.filter { $0.score != nil }.count
        alphabetIndexLetters = (65...90).compactMap { UnicodeScalar($0).map(String.init) } + ["#"]

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredItems = query.isEmpty ? items : items.filter {
            $0.title.localizedCaseInsensitiveContains(query)
        }
        let visibleItems = filteredItems.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        let grouped = Dictionary(grouping: visibleItems) { item in
            Self.sectionTitle(for: item.title)
        }

        sections = grouped.keys.sorted(by: Self.sectionSort).map { title in
            LibrarySection(title: title, items: grouped[title] ?? [])
        }
        indexLetters = sections.map(\.title)

        if selectedFilter != .all, !allItems.isEmpty {
            emptyLibraryTitle = "No \(selectedFilter.title) Yet"
            emptyLibrarySystemImage = selectedFilter.systemImage
            emptyLibraryDescription = "Change the filter or add a matching item to this library."
        } else {
            emptyLibraryTitle = "No Media Yet"
            emptyLibrarySystemImage = "square.stack"
            emptyLibraryDescription = "Add something to your library and it will show up here."
        }
    }

    private static func sectionTitle(for title: String) -> String {
        guard let first = title.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "#"
        }

        let letter = String(first).uppercased()
        return letter.rangeOfCharacter(from: .letters) == nil ? "#" : letter
    }

    private static func sectionSort(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == "#" { return false }
        if rhs == "#" { return true }
        return lhs < rhs
    }
}

struct LibrarySection: Equatable, Identifiable {
    let title: String
    let items: [MediaSummary]

    var id: String { title }
}

private struct LibraryChrome: View {
    let baseURLString: String
    @Binding var selectedFilter: MediaType
    let onOpenConnectionSettings: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    onOpenConnectionSettings()
                } label: {
                    ServerStatusPill(
                        connectionStatus: .connected,
                        baseURLString: baseURLString
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("server-status-pill")
                .accessibilityLabel(ServerStatusPill.displayLabel(for: baseURLString))

                Spacer(minLength: 0)

                LibraryFilterControl(selectedFilter: $selectedFilter)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(.clear)
    }
}

private struct LibrarySectionView: View {
    let section: LibrarySection
    let makeDetailViewModel: (MediaSummary) -> MediaDetailViewModel?
    let onEdit: (MediaSummary, MediaDetailViewModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            LazyVStack(spacing: 14) {
                ForEach(section.items) { item in
                    if let detailViewModel = makeDetailViewModel(item) {
                        MediaRowView(item: item) { _ in
                            onEdit(item, detailViewModel)
                        }
                        .accessibilityIdentifier("library-card-\(item.id)")
                    } else {
                        MediaRowView(item: item)
                            .accessibilityIdentifier("library-card-\(item.id)")
                    }
                }
            }
        }
    }
}

private struct AlphabetIndexRail: View {
    let letters: [String]
    let enabledLetters: Set<String>
    let selectedLetter: String
    let onSelect: (String) -> Void

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 2) {
                ForEach(letters, id: \.self) { letter in
                    Button {
                        onSelect(letter)
                    } label: {
                        Text(letter)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(foregroundStyle(for: letter))
                            .frame(width: 24, height: 15)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("library-index-\(letter)")
                    .accessibilityLabel(letter == "#" ? "Number sign" : letter)
                    .accessibilityHint(enabledLetters.contains(letter) ? "Jump to \(letter)" : "No items for \(letter)")
                }
            }
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.82))
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let letterHeight = max(proxy.size.height / CGFloat(max(letters.count, 1)), 1)
                        let index = min(max(Int(value.location.y / letterHeight), 0), max(letters.count - 1, 0))
                        guard letters.indices.contains(index) else { return }
                        onSelect(letters[index])
                    }
            )
        }
        .frame(width: 32, height: CGFloat(letters.count) * 16 + 16)
        .padding(.trailing, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Alphabet index")
    }

    private func foregroundStyle(for letter: String) -> Color {
        if letter == selectedLetter {
            return .accentColor
        }

        return enabledLetters.contains(letter) ? .secondary : Color.secondary.opacity(0.32)
    }
}

private struct LibraryFilterControl: View {
    @Binding var selectedFilter: MediaType

    var body: some View {
        Menu {
            ForEach(MediaType.allCases) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    HStack {
                        Label(filter.title, systemImage: filter.systemImage)
                        if selectedFilter == filter {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedFilter.systemImage)
                    .font(.caption.weight(.semibold))
                Text(selectedFilter.title)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .accessibilityIdentifier("library-filter-control")
    }
}

struct ServerStatusPill: View {
    let connectionStatus: ConnectionStatus
    let baseURLString: String

    var body: some View {
        let presentation = ServerStatusPresentation(
            connectionStatus: connectionStatus,
            baseURLString: baseURLString
        )

        HStack(spacing: 8) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(indicatorColor(for: presentation.tone))

            Text(presentation.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(glassStyle(for: presentation.tone), in: .capsule)
    }

    private func glassStyle(for tone: ServerStatusPresentation.Tone) -> Glass {
        switch tone {
        case .connected:
            return .regular.interactive()
        case .disconnected:
            return .regular.tint(Color.red.opacity(0.10)).interactive()
        }
    }

    private func indicatorColor(for tone: ServerStatusPresentation.Tone) -> Color {
        switch tone {
        case .connected:
            return Color(red: 0.20, green: 0.64, blue: 0.36)
        case .disconnected:
            return Color.red
        }
    }

    nonisolated static func displayLabel(for baseURLString: String) -> String {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let host = URL(string: trimmed)?.host, !host.isEmpty {
            return host
        }

        return trimmed
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

struct ServerStatusPresentation: Equatable {
    enum Tone: Equatable {
        case connected
        case disconnected
    }

    let title: String
    let systemImage: String
    let tone: Tone

    init(connectionStatus: ConnectionStatus, baseURLString: String) {
        switch connectionStatus {
        case .connected:
            let label = ServerStatusPill.displayLabel(for: baseURLString)
            title = label.isEmpty ? "Connected" : label
            systemImage = "circle.fill"
            tone = .connected
        case .disconnected:
            title = "Disconnected"
            systemImage = "wifi.slash"
            tone = .disconnected
        }
    }
}

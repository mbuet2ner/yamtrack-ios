import SwiftUI

struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    let baseURLString: String
    let sessionWarningMessage: String?
    let onOpenAdd: () -> Void
    let onOpenConnectionSettings: () -> Void
    @State private var trackingEditor: LibraryTrackingEditorState?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleSection

                if let errorMessage = viewModel.errorMessage, !viewModel.items.isEmpty {
                    inlineErrorBanner(message: errorMessage)
                }

                if let sessionWarningMessage, !sessionWarningMessage.isEmpty {
                    sessionWarningBanner(message: sessionWarningMessage)
                }

                LazyVStack(spacing: 14) {
                    ForEach(viewModel.items) { item in
                        if let detailViewModel = viewModel.makeDetailViewModel(for: item) {
                            MediaRowView(item: item) { _ in
                                trackingEditor = LibraryTrackingEditorState(
                                    id: item.id,
                                    item: item,
                                    viewModel: detailViewModel
                                )
                            }
                            .accessibilityIdentifier("library-card-\(item.id)")
                        } else {
                            MediaRowView(item: item)
                                .accessibilityIdentifier("library-card-\(item.id)")
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 90)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .overlay(alignment: .top) {
            stickyChrome
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomChrome
        }
        .overlay {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            } else if viewModel.items.isEmpty, let errorMessage = viewModel.errorMessage {
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
            } else if !viewModel.isLoading && viewModel.items.isEmpty {
                libraryStateCard(
                    title: "No Media Yet",
                    systemImage: "square.stack",
                    description: "Add something to your library and it will show up here."
                ) {
                    Button("Add Media") {
                        onOpenAdd()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .task {
            await viewModel.load()
        }
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

    private var bottomChrome: some View {
        BottomChrome {
            Spacer(minLength: 0)

            FloatingAddOrb {
                onOpenAdd()
            }
        }
    }

    private var stickyChrome: some View {
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

                LibraryFilterControl(selectedFilter: $viewModel.selectedFilter)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 12)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Library")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                Text("\(viewModel.items.count) tracked")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func inlineErrorBanner(message: String) -> some View {
        ContentSurface {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sessionWarningBanner(message: String) -> some View {
        ContentSurface {
            Label(message, systemImage: "exclamationmark.shield.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

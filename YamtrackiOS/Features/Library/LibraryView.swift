import SwiftUI

struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    let baseURLString: String
    let onOpenAdd: () -> Void
    let onOpenConnectionSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                controlBar

                if let errorMessage = viewModel.errorMessage, !viewModel.items.isEmpty {
                    inlineErrorBanner(message: errorMessage)
                }

                LazyVStack(spacing: 14) {
                    ForEach(viewModel.items) { item in
                        if let detailViewModel = viewModel.makeDetailViewModel(for: item) {
                            NavigationLink {
                                MediaDetailView(viewModel: detailViewModel)
                            } label: {
                                MediaRowView(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("library-card-\(item.id)")
                        } else {
                            MediaRowView(item: item)
                                .accessibilityIdentifier("library-card-\(item.id)")
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(libraryBackground)
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
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Try Again") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.borderedProminent)
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
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controlBar: some View {
        GlassSurface {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
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

                    Text("Library")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("\(viewModel.items.count) tracked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    Button {
                        onOpenAdd()
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.accentColor.opacity(0.16))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("library-add-media-button")

                    Picker("Filter", selection: $viewModel.selectedFilter) {
                        ForEach(MediaType.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library-control-bar")
    }

    private var libraryBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(red: 0.96, green: 0.95, blue: 0.93),
                Color(.secondarySystemBackground).opacity(0.55),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func inlineErrorBanner(message: String) -> some View {
        GlassSurface {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
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
            GlassSurface {
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

struct ServerStatusPill: View {
    let connectionStatus: ConnectionStatus
    let baseURLString: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    private var title: String {
        switch connectionStatus {
        case .connected:
            let label = Self.displayLabel(for: baseURLString)
            return label.isEmpty ? "Connected" : label
        case .disconnected:
            return "Disconnected"
        }
    }

    private var indicatorColor: Color {
        switch connectionStatus {
        case .connected:
            return Color(red: 0.20, green: 0.64, blue: 0.36)
        case .disconnected:
            return Color.red
        }
    }

    private var backgroundColor: Color {
        switch connectionStatus {
        case .connected:
            return Color(red: 0.86, green: 0.95, blue: 0.88)
        case .disconnected:
            return Color.red.opacity(0.10)
        }
    }

    private var borderColor: Color {
        switch connectionStatus {
        case .connected:
            return Color(red: 0.20, green: 0.64, blue: 0.36).opacity(0.18)
        case .disconnected:
            return Color.red.opacity(0.14)
        }
    }

    static func displayLabel(for baseURLString: String) -> String {
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

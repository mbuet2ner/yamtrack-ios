import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .library
    @State private var isShowingConnectionSheet = false
    @State private var session: SessionController
    @State private var viewModel: RootViewModel

    init(session: SessionController, apiClient: APIClient = .live) {
        _session = State(initialValue: session)
        _viewModel = State(initialValue: RootViewModel(apiClient: apiClient))
    }

    var body: some View {
        Group {
            if viewModel.isRestoringSession {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                appShell
            }
        }
        .task {
            await viewModel.restoreSession(using: session)
            if !session.hasPersistedSession {
                selectedTab = .library
                isShowingConnectionSheet = true
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .addMedia, let libraryViewModel = viewModel.libraryViewModel else { return }
            libraryViewModel.makeAddMediaViewModel().reset()
        }
        .onChange(of: session.connectionStatus) { _, _ in
            viewModel.sessionDidChange(using: session)
            if session.hasPersistedSession {
                isShowingConnectionSheet = false
            }
        }
        .onChange(of: session.hasPersistedSession) { _, hasPersistedSession in
            if !hasPersistedSession {
                selectedTab = .library
                isShowingConnectionSheet = true
            }
        }
        .sheet(isPresented: $isShowingConnectionSheet) {
            NavigationStack {
                SetupView(
                    session: session,
                    onDismiss: { isShowingConnectionSheet = false },
                    onConnectionUpdated: {
                        viewModel.sessionDidChange(using: session)
                        isShowingConnectionSheet = false
                    }
                )
            }
        }
    }

    private var appShell: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                libraryContent
            }
            .tabItem { Label("Library", systemImage: "square.stack.fill") }
            .tag(AppTab.library)

            NavigationStack {
                addMediaContent
            }
            .tabItem { Label("Add", systemImage: "plus.square.fill") }
            .tag(AppTab.addMedia)
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        if let libraryViewModel = viewModel.libraryViewModel {
            LibraryView(
                viewModel: libraryViewModel,
                baseURLString: session.baseURLString,
                onOpenAdd: { selectedTab = .addMedia },
                onOpenConnectionSettings: { isShowingConnectionSheet = true }
            )
        } else {
            DisconnectedLibraryView(
                baseURLString: session.baseURLString,
                onOpenConnectionSettings: { isShowingConnectionSheet = true }
            )
        }
    }

    @ViewBuilder
    private var addMediaContent: some View {
        if let libraryViewModel = viewModel.libraryViewModel {
            AddMediaView(
                viewModel: libraryViewModel.makeAddMediaViewModel(),
                showsCloseButton: false,
                onMediaCreated: {
                    libraryViewModel.makeAddMediaViewModel().reset()
                    selectedTab = .library
                }
            )
        } else {
            ScrollView {
                ConnectionRequiredView(
                    title: "Reconnect To Add Media",
                    description: "Reconnect to your Yamtrack server before searching providers or creating new entries.",
                    actionTitle: "Open Connection Settings",
                    onOpenConnectionSettings: { isShowingConnectionSheet = true }
                )
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(addMediaPlaceholderBackground)
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var addMediaPlaceholderBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(red: 0.98, green: 0.94, blue: 0.90),
                Color(.secondarySystemBackground).opacity(0.55),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct DisconnectedLibraryView: View {
    let baseURLString: String
    let onOpenConnectionSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                controlBar

                ConnectionRequiredView(
                    title: "Reconnect To Load Your Library",
                    description: description,
                    actionTitle: "Open Connection Settings",
                    onOpenConnectionSettings: onOpenConnectionSettings
                )
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(libraryBackground)
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controlBar: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    onOpenConnectionSettings()
                } label: {
                    ServerStatusPill(
                        connectionStatus: .disconnected,
                        baseURLString: baseURLString
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("server-status-pill")
                .accessibilityLabel("Disconnected")

                Text("Library")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Reconnect to refresh your tracked media and open detail views again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var description: String {
        let label = ServerStatusPill.displayLabel(for: baseURLString)
        if label.isEmpty {
            return "Your saved server details are still on this device. Open connection settings to reconnect."
        }

        return "Your saved connection to \(label) is still on this device. Open connection settings to reconnect."
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
}

private struct ConnectionRequiredView: View {
    let title: String
    let description: String
    let actionTitle: String
    let onOpenConnectionSettings: () -> Void

    var body: some View {
        GlassSurface {
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(actionTitle) {
                    onOpenConnectionSettings()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

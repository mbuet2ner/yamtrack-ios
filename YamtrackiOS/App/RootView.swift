import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .library
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
            } else if session.hasPersistedSession, let libraryViewModel = viewModel.libraryViewModel {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        LibraryView(
                            viewModel: libraryViewModel,
                            onOpenAdd: { selectedTab = .addMedia },
                            onOpenSettings: { selectedTab = .settings },
                            onLogout: { session.logout() }
                        )
                    }
                    .tabItem { Label("Library", systemImage: "square.stack.fill") }
                    .tag(AppTab.library)

                    NavigationStack {
                        AddMediaView(
                            viewModel: libraryViewModel.makeAddMediaViewModel(),
                            showsCloseButton: false,
                            onMediaCreated: {
                                libraryViewModel.makeAddMediaViewModel().reset()
                                selectedTab = .library
                            }
                        )
                    }
                    .tabItem { Label("Add", systemImage: "plus.square.fill") }
                    .tag(AppTab.addMedia)

                    NavigationStack {
                        SettingsHomeView(session: session)
                    }
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
                }
            } else {
                NavigationStack {
                    SetupView(session: session)
                }
            }
        }
        .task {
            await viewModel.restoreSession(using: session)
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .addMedia, let libraryViewModel = viewModel.libraryViewModel else { return }
            libraryViewModel.makeAddMediaViewModel().reset()
        }
        .onChange(of: session.hasPersistedSession) { _, _ in
            viewModel.sessionDidChange(using: session)
        }
    }
}

private struct SettingsHomeView: View {
    @Bindable var session: SessionController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Account")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                GlassSurface {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Connection", systemImage: "network")
                            .font(.headline)

                        settingsValue(label: "Server", value: session.baseURLString.isEmpty ? "Not connected" : session.baseURLString)
                        settingsValue(label: "Token", value: maskedToken)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings-connection-card")

                GlassSurface {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Actions", systemImage: "person.crop.circle")
                            .font(.headline)

                        Text("Sign out of this Yamtrack server on this device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("Log Out", role: .destructive) {
                            session.logout()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings-actions-card")
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(settingsBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var maskedToken: String {
        guard !session.token.isEmpty else { return "Unavailable" }
        let suffix = session.token.suffix(4)
        return "••••••••\(suffix)"
    }

    private var settingsBackground: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground).opacity(0.55),
                Color(.systemBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func settingsValue(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }
}

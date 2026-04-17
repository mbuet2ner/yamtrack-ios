import SwiftUI

struct RootView: View {
    @State private var isShowingConnectionSheet = false
    @State private var session: SessionController
    @State private var viewModel: RootViewModel
    private let addOrbPresentation = FloatingActionPresentation.addMedia

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
                isShowingConnectionSheet = true
            }
        }
        .onChange(of: session.connectionStatus) { _, _ in
            viewModel.sessionDidChange(using: session)
            if session.connectionStatus == .connected {
                isShowingConnectionSheet = false
            }
        }
        .onChange(of: session.hasPersistedSession) { _, hasPersistedSession in
            if !hasPersistedSession, session.connectionStatus != .connected {
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
        .sheet(isPresented: addMediaSheetBinding) {
            if let libraryViewModel = viewModel.libraryViewModel {
                NavigationStack {
                    AddMediaView(viewModel: libraryViewModel.makeAddMediaViewModel())
                }
                .presentationBackground(Color(uiColor: .systemGroupedBackground))
            }
        }
    }

    private var appShell: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                libraryContent
            }

            if shouldShowFloatingAddOrb {
                FloatingAddOrb {
                    viewModel.libraryViewModel?.presentAddMedia()
                }
                .padding(.trailing, Theme.screenPadding + 2)
                .padding(.bottom, addOrbPresentation.bottomOffset)
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        if let libraryViewModel = viewModel.libraryViewModel {
            LibraryView(
                viewModel: libraryViewModel,
                baseURLString: session.baseURLString,
                sessionWarningMessage: session.sessionWarningMessage,
                onOpenAdd: { libraryViewModel.presentAddMedia() },
                onOpenConnectionSettings: { isShowingConnectionSheet = true }
            )
        } else {
            DisconnectedLibraryView(
                baseURLString: session.baseURLString,
                onOpenConnectionSettings: { isShowingConnectionSheet = true }
            )
        }
    }

    private var shouldShowFloatingAddOrb: Bool {
        viewModel.libraryViewModel != nil && !isShowingConnectionSheet
    }

    private var addMediaSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.libraryViewModel?.isShowingAddMedia ?? false },
            set: { isPresented in
                if !isPresented {
                    viewModel.libraryViewModel?.dismissAddMedia()
                }
            }
        )
    }
}

private struct DisconnectedLibraryView: View {
    let baseURLString: String
    let onOpenConnectionSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Library")
                    .font(.largeTitle.weight(.bold))

                Text("Reconnect to refresh your tracked media and open detail views again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

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

                ConnectionRequiredView(
                    title: "Reconnect To Load Your Library",
                    description: description,
                    actionTitle: "Open Connection Settings",
                    onOpenConnectionSettings: onOpenConnectionSettings
                )
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var description: String {
        let label = ServerStatusPill.displayLabel(for: baseURLString)
        if label.isEmpty {
            return "Your saved server details are still on this device. Open connection settings to reconnect."
        }

        return "Your saved connection to \(label) is still on this device. Open connection settings to reconnect."
    }
}

private struct ConnectionRequiredView: View {
    let title: String
    let description: String
    let actionTitle: String
    let onOpenConnectionSettings: () -> Void

    var body: some View {
        ContentSurface {
            VStack(spacing: 18) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
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
                .buttonStyle(.glassProminent)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

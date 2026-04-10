import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .library
    @State private var session: SessionController
    @State private var libraryViewModel: LibraryViewModel?
    @State private var isRestoringSession = true

    init(session: SessionController) {
        _session = State(initialValue: session)
    }

    var body: some View {
        Group {
            if isRestoringSession {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if session.hasPersistedSession, let libraryViewModel {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        LibraryView(viewModel: libraryViewModel)
                    }
                    .tabItem { Label("Library", systemImage: "square.stack.fill") }
                    .tag(AppTab.library)

                    NavigationStack {
                        Text("Search")
                            .navigationTitle("Search")
                    }
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(AppTab.search)

                    NavigationStack {
                        Text("Settings")
                            .navigationTitle("Settings")
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
            await session.restoreCredentials()
            if session.hasPersistedSession,
               let baseURL = URL(string: session.baseURLString)
            {
                libraryViewModel = LibraryViewModel(
                    apiClient: .live,
                    credentials: SessionCredentials(baseURL: baseURL, token: session.token)
                )
            } else {
                libraryViewModel = nil
            }
            isRestoringSession = false
        }
    }
}

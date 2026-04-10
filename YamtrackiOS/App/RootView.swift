import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .library
    @State private var session: SessionController
    @State private var viewModel = RootViewModel()

    init(session: SessionController) {
        _session = State(initialValue: session)
    }

    var body: some View {
        Group {
            if viewModel.isRestoringSession {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if session.hasPersistedSession, let libraryViewModel = viewModel.libraryViewModel {
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
            await viewModel.restoreSession(using: session)
        }
        .onChange(of: session.hasPersistedSession) { _, _ in
            viewModel.sessionDidChange(using: session)
        }
    }
}

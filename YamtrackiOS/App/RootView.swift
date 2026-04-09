import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .library
    @State private var session: SessionController
    @State private var didRestoreSession = false

    init(session: SessionController) {
        _session = State(initialValue: session)
    }

    var body: some View {
        Group {
            if didRestoreSession && session.hasPersistedSession {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        Text("Library")
                            .navigationTitle("Library")
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
            didRestoreSession = true
        }
    }
}

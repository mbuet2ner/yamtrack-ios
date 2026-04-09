import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .library

    var body: some View {
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
    }
}

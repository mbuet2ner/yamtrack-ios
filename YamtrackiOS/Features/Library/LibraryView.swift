import SwiftUI

struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel

    var body: some View {
        List {
            if let errorMessage = viewModel.errorMessage, !viewModel.items.isEmpty {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            ForEach(viewModel.items) { item in
                if let detailViewModel = viewModel.makeDetailViewModel(for: item) {
                    NavigationLink {
                        MediaDetailView(viewModel: detailViewModel)
                    } label: {
                        MediaRowView(item: item)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(.init(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    MediaRowView(item: item)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage, viewModel.items.isEmpty {
                ContentUnavailableView(
                    "Library Error",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
            } else if !viewModel.isLoading && viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No Media",
                    systemImage: "square.stack"
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker("Filter", selection: $viewModel.selectedFilter) {
                    ForEach(MediaType.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
        .navigationTitle("Library")
    }
}

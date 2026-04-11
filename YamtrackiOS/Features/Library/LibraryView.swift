import SwiftUI

struct LibraryView: View {
    @Bindable var viewModel: LibraryViewModel
    let onOpenAdd: () -> Void
    let onOpenSettings: () -> Void
    let onLogout: () -> Void

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
                    description: viewModel.isAuthenticationError ? "Your Yamtrack session is no longer valid. Open Settings or log out to reconnect." : errorMessage
                ) {
                    if viewModel.isAuthenticationError {
                        Button("Open Settings") {
                            onOpenSettings()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Log Out", role: .destructive) {
                            onLogout()
                        }
                        .buttonStyle(.bordered)
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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Library")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("\(viewModel.items.count) tracked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

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

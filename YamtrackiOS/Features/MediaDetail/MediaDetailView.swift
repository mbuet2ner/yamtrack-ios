import SwiftUI

struct MediaDetailView: View {
    @Bindable var viewModel: MediaDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let detail = viewModel.detail {
                    GlassSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                // Task 5 only needs the affordance, not the action plumbing yet.
                            } label: {
                                Label(viewModel.primaryActionTitle, systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                            metadataRow(title: "Status", value: detail.status ?? "Unknown")
                            metadataRow(title: "Progress", value: viewModel.progressSummary ?? "Unknown")

                            if let overview = detail.overview, !overview.isEmpty {
                                Text(overview)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let seasons = detail.seasons, !seasons.isEmpty {
                        GlassSurface {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Seasons")
                                    .font(.headline)

                                ForEach(seasons) { season in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(season.title)
                                            .font(.subheadline.bold())
                                        if let progress = season.progress {
                                            Text("Progress: \(progress)")
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    if season.id != seasons.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    GlassSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Media Detail Error", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundStyle(.red)

                            Text(errorMessage)
                                .foregroundStyle(.secondary)

                            Button {
                                Task {
                                    await viewModel.load()
                                }
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("media-detail-retry-button")
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                }
            }
            .padding(Theme.screenPadding)
        }
        .navigationTitle(viewModel.title.isEmpty ? "Detail" : viewModel.title)
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title.isEmpty ? "Loading Detail" : viewModel.title)
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            if let progressSummary = viewModel.progressSummary {
                Text(progressSummary)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metadataRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

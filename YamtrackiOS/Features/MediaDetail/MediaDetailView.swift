import SwiftUI

struct MediaDetailView: View {
    @Bindable var viewModel: MediaDetailViewModel
    @State private var isShowingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let detail = viewModel.detail {
                    GlassSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                isShowingEditor = true
                            } label: {
                                Label(viewModel.primaryActionTitle, systemImage: "slider.horizontal.3")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("media-detail-primary-action-button")

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
        .sheet(isPresented: $isShowingEditor) {
            MediaDetailEditorSheet(viewModel: viewModel)
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
                    .accessibilityIdentifier("media-detail-progress-summary")
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

private struct MediaDetailEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MediaDetailViewModel
    @State private var selectedStatus: MediaSummary.Status
    @State private var progressText: String
    @State private var scoreText: String
    @State private var notes: String

    init(viewModel: MediaDetailViewModel) {
        self.viewModel = viewModel
        _selectedStatus = State(initialValue: viewModel.detail?.trackingStatus ?? .planning)
        _progressText = State(initialValue: viewModel.detail?.progress.map(String.init) ?? "")
        _scoreText = State(initialValue: viewModel.detail?.score.map { String($0) } ?? "")
        _notes = State(initialValue: viewModel.detail?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(MediaSummary.Status.allCases, id: \.self) { status in
                        Text(status.title).tag(status)
                    }
                }

                TextField("Progress", text: $progressText)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("media-detail-progress-field")

                TextField("Score", text: $scoreText)
                    .keyboardType(.decimalPad)

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)

                if let saveErrorMessage = viewModel.saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            do {
                                try await viewModel.saveEdits(
                                    MediaUpdateRequest(
                                        status: selectedStatus,
                                        progress: Int(progressText),
                                        score: Double(scoreText),
                                        notes: notes.nilIfBlank
                                    )
                                )
                                dismiss()
                            } catch {
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                    .accessibilityIdentifier("media-detail-save-button")
                }
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

import SwiftUI

struct MediaDetailView: View {
    @Bindable var viewModel: MediaDetailViewModel
    @State private var isShowingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let detail = viewModel.detail {
                    ContentSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            metadataRow(title: "Status", value: detail.status ?? "Unknown")
                            metadataRow(title: "Progress", value: viewModel.progressSummary ?? "Unknown")

                            if let overview = detail.overview, !overview.isEmpty {
                                Divider()

                                Text(overview)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if let seasons = detail.seasons, !seasons.isEmpty {
                        ContentSurface {
                            VStack(alignment: .leading, spacing: 12) {
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
                    ContentSurface {
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
                            .buttonStyle(.glassProminent)
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
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.title.isEmpty ? "Detail" : viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $isShowingEditor) {
            MediaDetailEditorSheet(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.detail != nil {
                    Button(viewModel.primaryActionTitle, systemImage: "slider.horizontal.3") {
                        isShowingEditor = true
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("media-detail-primary-action-button")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.title.isEmpty ? "Loading Detail" : viewModel.title)
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                if let status = viewModel.detail?.trackingStatus {
                    metadataChip(MediaMetadataChipPresentation(
                        text: status.title,
                        systemImage: statusChipIcon(for: status),
                        tone: statusChipTone(for: status)
                    ))
                }

                if let progressSummary = viewModel.progressSummary {
                    metadataChip(
                        MediaMetadataChipPresentation(
                            text: progressSummary,
                            systemImage: "chart.bar.fill",
                            tone: .accent
                        )
                    )
                    .accessibilityIdentifier("media-detail-progress-summary")
                }
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

    private func metadataChip(_ chip: MediaMetadataChipPresentation) -> some View {
        Label(chip.text, systemImage: chip.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(chip.foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(chip.backgroundColor))
    }

    private func statusChipIcon(for status: MediaSummary.Status) -> String {
        switch status {
        case .planning:
            return "clock.fill"
        case .inProgress:
            return "play.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .dropped:
            return "xmark.circle.fill"
        }
    }

    private func statusChipTone(for status: MediaSummary.Status) -> MediaMetadataChipPresentation.Tone {
        switch status {
        case .planning:
            return .neutral
        case .inProgress:
            return .accent
        case .paused, .dropped:
            return .subdued
        case .completed:
            return .positive
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

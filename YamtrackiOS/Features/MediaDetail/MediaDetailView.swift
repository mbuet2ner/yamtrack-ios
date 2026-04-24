import SwiftUI

struct MediaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MediaDetailViewModel
    @State private var isShowingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailChrome
                header

                if let detail = viewModel.detail {
                    ContentSurface {
                        VStack(alignment: .leading, spacing: 14) {
                            trackingActionRow(
                                title: "Status",
                                value: detail.trackingStatus?.title ?? "Unknown",
                                systemImage: detail.trackingStatus?.systemImage ?? "circle.dashed"
                            )
                            trackingActionRow(
                                title: "Progress",
                                value: viewModel.progressSummary ?? "Unknown",
                                systemImage: "chart.bar.fill"
                            )

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
            TrackingEditorSheet(viewModel: viewModel)
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var detailChrome: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.semibold))
                    .frame(width: 64, height: 64)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityIdentifier("media-detail-back-button")

            Spacer(minLength: 0)

            Text(viewModel.title.isEmpty ? "Detail" : viewModel.title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: 180)

            Spacer(minLength: 0)

            Button {
                isShowingEditor = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.weight(.semibold))
                    .frame(width: 64, height: 64)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityIdentifier("media-detail-tracking-button")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.title.isEmpty ? "Loading Detail" : viewModel.title)
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                if let status = viewModel.detail?.trackingStatus {
                    Button {
                        isShowingEditor = true
                    } label: {
                        metadataChip(MediaMetadataChipPresentation(
                            text: status.title,
                            systemImage: status.systemImage,
                            tone: statusChipTone(for: status),
                            kind: .status
                        ))
                    }
                    .buttonStyle(.plain)
                }

                if let progressSummary = viewModel.progressSummary {
                    Button {
                        isShowingEditor = true
                    } label: {
                        metadataChip(
                            MediaMetadataChipPresentation(
                                text: progressSummary,
                                systemImage: "chart.bar.fill",
                                tone: .accent,
                                kind: .progress
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("media-detail-progress-summary")
                }
            }
        }
    }

    private func trackingActionRow(title: String, value: String, systemImage: String) -> some View {
        Button {
            isShowingEditor = true
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .font(.title3.weight(.medium))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title == "Progress" ? "media-detail-progress-summary" : "")
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

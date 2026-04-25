import SwiftUI

struct TrackingEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MediaDetailViewModel
    @State private var selectedStatus: MediaSummary.Status
    @State private var progressValue: Int
    @State private var scoreValue: Double?
    @State private var notes: String

    init(
        viewModel: MediaDetailViewModel,
        status: MediaSummary.Status? = nil,
        progress: Int? = nil,
        score: Double? = nil,
        notes: String? = nil
    ) {
        self.viewModel = viewModel
        _selectedStatus = State(initialValue: status ?? viewModel.detail?.trackingStatus ?? .planning)
        _progressValue = State(initialValue: max(progress ?? viewModel.detail?.progress ?? 0, 0))
        _scoreValue = State(initialValue: score ?? viewModel.detail?.score)
        _notes = State(initialValue: notes ?? viewModel.detail?.notes ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header

                GlassSurface {
                    VStack(alignment: .leading, spacing: 20) {
                        statusControl

                        if usesBinaryProgress {
                            starScoreControl
                        } else {
                            HStack(alignment: .top, spacing: 14) {
                                progressControl
                            }
                            starScoreControl
                        }

                        notesControl
                    }
                }

                if let saveErrorMessage = viewModel.saveErrorMessage {
                    Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .presentationDetents(usesBinaryProgress ? [.height(430), .medium, .large] : [.height(620), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(uiColor: .systemGroupedBackground).opacity(0.98))
    }

    private var header: some View {
        GlassEffectContainer(spacing: 14) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .font(.headline.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .glassEffect(.regular.interactive(), in: .capsule)

                Spacer(minLength: 0)

                Text("Tracking")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Button("Save") {
                    Task { await save() }
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 22)
                .frame(height: 52)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.14)).interactive(), in: .capsule)
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("media-detail-save-button")
            }
        }
    }

    private var statusControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Status", systemImage: selectedStatus.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            GlassEffectContainer(spacing: 8) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(statusRows, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(row, id: \.self) { status in
                                statusButton(for: status)
                            }
                        }
                    }
                }
            }
        }
    }

    private func statusButton(for status: MediaSummary.Status) -> some View {
        let isSelected = status == selectedStatus

        return Button {
            selectedStatus = status
            if usesBinaryProgress {
                progressValue = status == .completed ? 1 : 0
            }
        } label: {
            Label(status.title, systemImage: status.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(Color.accentColor.opacity(0.16)).interactive() : .regular.interactive(),
            in: .capsule
        )
        .accessibilityIdentifier("media-detail-status-\(status.rawValue)-button")
    }

    private var progressControl: some View {
        LiquidMeter(
            title: "Progress",
            valueText: progressDescription,
            systemImage: "chart.bar.fill",
            tint: .accentColor,
            value: progressBinding,
            range: 0...Double(progressMaximum),
            step: 1
        )
        .accessibilityIdentifier("media-detail-progress-field")
    }

    private var starScoreControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Score", systemImage: "star.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(scoreText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            StarRatingControl(score: $scoreValue)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private var notesControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Notes", systemImage: "text.alignleft")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Add a thought, context, or reminder", text: $notes, axis: .vertical)
                .font(.body.weight(.medium))
                .lineLimit(3...6)
                .padding(14)
                .frame(minHeight: 96, alignment: .topLeading)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
    }

    private func save() async {
        do {
            try await viewModel.saveEdits(
                MediaUpdateRequest(
                    status: selectedStatus,
                    progress: savedProgressValue,
                    score: scoreValue,
                    notes: notesNilIfBlank
                )
            )
            dismiss()
        } catch {
        }
    }

    private var notesNilIfBlank: String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var mediaType: MediaType? {
        MediaType(rawValue: viewModel.mediaType)
    }

    private var usesBinaryProgress: Bool {
        mediaType == .movie
    }

    private var statusRows: [[MediaSummary.Status]] {
        [
            [.planning, .inProgress],
            [.paused, .completed],
            [.dropped]
        ]
    }

    private var savedProgressValue: Int {
        usesBinaryProgress ? (selectedStatus == .completed ? 1 : 0) : progressValue
    }

    private var progressDescription: String {
        switch mediaType {
        case .movie:
            return progressValue > 0 ? "Watched" : "Not watched"
        case .book:
            return "\(progressValue) read"
        case .tv, .anime:
            return "\(progressValue) episodes"
        case .manga, .comic:
            return "\(progressValue) chapters"
        case .game, .boardgame:
            return "\(progressValue) played"
        case .all, .none:
            return "Progress \(progressValue)"
        }
    }

    private var scoreText: String {
        guard let scoreValue else { return "No score" }
        return "\(scoreValue.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(scoreValue.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)))) / 10"
    }

    private var progressBinding: Binding<Double> {
        Binding(
            get: { Double(progressValue) },
            set: { progressValue = min(max(Int($0.rounded()), 0), progressMaximum) }
        )
    }

    private var progressMaximum: Int {
        if let totalCount = viewModel.detail?.totalCount, totalCount > 0 {
            return max(totalCount, progressValue)
        }

        switch mediaType {
        case .movie:
            return 1
        case .book, .manga, .comic:
            return max(progressValue, 100)
        case .tv, .anime:
            return max(progressValue, 24)
        case .game, .boardgame:
            return max(progressValue, 10)
        case .all, .none:
            return max(progressValue, 10)
        }
    }

    private func scoreStarName(for index: Int) -> String {
        guard let scoreValue else { return "star" }
        let starValue = Double(index) * 2
        if scoreValue >= starValue {
            return "star.fill"
        }
        if scoreValue >= starValue - 1 {
            return "star.leadinghalf.filled"
        }
        return "star"
    }
}

private struct StarRatingControl: View {
    @Binding var score: Double?

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        score = Double(index * 2)
                    } label: {
                        Image(systemName: starName(for: index))
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                    .accessibilityLabel("\(index * 2) out of 10")
                    .accessibilityIdentifier("media-detail-score-\(index * 2)-button")
                    .accessibilityAddTraits(score == Double(index * 2) ? .isSelected : [])
                }
            }
        }
    }

    private func starName(for index: Int) -> String {
        guard let score else { return "star" }
        let starValue = Double(index) * 2
        if score >= starValue {
            return "star.fill"
        }
        if score >= starValue - 1 {
            return "star.leadinghalf.filled"
        }
        return "star"
    }
}

private struct LiquidMeter: View {
    let title: String
    let valueText: String
    let systemImage: String
    let tint: Color
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            GeometryReader { proxy in
                let fillHeight = proxy.size.height * normalizedValue

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.primary.opacity(0.04))

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.42),
                                    tint.opacity(0.18)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: fillHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: systemImage)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(tint)

                        Spacer()

                        Text(valueText)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            updateValue(locationY: drag.location.y, height: proxy.size.height)
                        }
                )
            }
            .frame(height: 174)
        }
        .frame(maxWidth: .infinity)
    }

    private var normalizedValue: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    private func updateValue(locationY: CGFloat, height: CGFloat) {
        guard height > 0 else { return }
        let normalized = min(max(1 - (locationY / height), 0), 1)
        let rawValue = range.lowerBound + (range.upperBound - range.lowerBound) * normalized
        let stepped = (rawValue / step).rounded() * step
        value = min(max(stepped, range.lowerBound), range.upperBound)
    }
}

extension MediaSummary.Status {
    var systemImage: String {
        switch self {
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
}

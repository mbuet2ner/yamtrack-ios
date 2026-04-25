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

                        if presentation.usesBinaryProgress {
                            ScoreEditorSection(score: $scoreValue)
                        } else {
                            ProgressEditorSection(
                                value: progressBinding,
                                maximum: progressMaximum,
                                valueText: progressDescription
                            )
                            ScoreEditorSection(score: $scoreValue)
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
        .presentationDetents(presentation.usesBinaryProgress ? [.height(430), .medium, .large] : [.height(620), .large])
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
            progressValue = TrackingEditorPresentation.progressAfterStatusChange(
                mediaType: mediaType,
                status: status,
                currentProgress: progressValue
            )
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
                    progress: TrackingEditorPresentation.savedProgress(
                        mediaType: mediaType,
                        status: selectedStatus,
                        progress: progressValue
                    ),
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

    private var statusRows: [[MediaSummary.Status]] {
        [
            [.planning, .inProgress],
            [.paused, .completed],
            [.dropped]
        ]
    }

    private var progressDescription: String {
        TrackingEditorPresentation.progressDescription(mediaType: mediaType, progress: progressValue)
    }

    private var progressBinding: Binding<Double> {
        Binding(
            get: { Double(progressValue) },
            set: { progressValue = TrackingEditorPresentation.clampedProgress(from: $0, maximum: progressMaximum) }
        )
    }

    private var progressMaximum: Int {
        TrackingEditorPresentation.progressMaximum(
            mediaType: mediaType,
            currentProgress: progressValue,
            totalCount: viewModel.detail?.totalCount
        )
    }

    private var presentation: TrackingEditorPresentation {
        TrackingEditorPresentation(mediaType: mediaType)
    }
}

struct TrackingEditorPresentation {
    enum ScoreAdjustment {
        case increment
        case decrement
    }

    let mediaType: MediaType?

    var usesBinaryProgress: Bool {
        mediaType == .movie
    }

    static func progressMaximum(mediaType: MediaType?, currentProgress: Int, totalCount: Int?) -> Int {
        if let totalCount, totalCount > 0 {
            return max(totalCount, currentProgress)
        }

        switch mediaType {
        case .movie:
            return 1
        case .book, .manga, .comic:
            return max(currentProgress, 100)
        case .tv, .anime:
            return max(currentProgress, 24)
        case .game, .boardgame, .all, .none:
            return max(currentProgress, 10)
        }
    }

    static func clampedProgress(from value: Double, maximum: Int) -> Int {
        min(max(Int(value.rounded()), 0), maximum)
    }

    static func progressDescription(mediaType: MediaType?, progress: Int) -> String {
        switch mediaType {
        case .movie:
            return progress > 0 ? "Watched" : "Not watched"
        case .book:
            return "\(progress) read"
        case .tv, .anime:
            return "\(progress) episodes"
        case .manga, .comic:
            return "\(progress) chapters"
        case .game, .boardgame:
            return "\(progress) played"
        case .all, .none:
            return "Progress \(progress)"
        }
    }

    static func progressAfterStatusChange(
        mediaType: MediaType?,
        status: MediaSummary.Status,
        currentProgress: Int
    ) -> Int {
        mediaType == .movie ? (status == .completed ? 1 : 0) : currentProgress
    }

    static func savedProgress(mediaType: MediaType?, status: MediaSummary.Status, progress: Int) -> Int {
        mediaType == .movie ? (status == .completed ? 1 : 0) : progress
    }

    static func scoreText(_ score: Double?) -> String {
        guard let score else { return "No score" }
        let hasFraction = score.truncatingRemainder(dividingBy: 1) != 0
        let formattedScore = score.formatted(
            .number
                .locale(Locale(identifier: "en_US_POSIX"))
                .precision(.fractionLength(hasFraction ? 1 : 0))
        )
        return "\(formattedScore) / 10"
    }

    static func scoreAfterAdjustment(_ score: Double?, direction: ScoreAdjustment) -> Double? {
        switch direction {
        case .increment:
            return min((score ?? 0) + 2, 10)
        case .decrement:
            let nextScore = (score ?? 0) - 2
            return nextScore <= 0 ? nil : nextScore
        }
    }

    static func scoreButtonAccessibilityValue(score: Double?, buttonScore: Double) -> String {
        score == buttonScore ? "Selected" : "Not selected"
    }

    static func starName(score: Double?, index: Int) -> String {
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

private struct ProgressEditorSection: View {
    @Binding var value: Double
    let maximum: Int
    let valueText: String

    var body: some View {
        LiquidMeter(
            title: "Progress",
            valueText: valueText,
            systemImage: "chart.bar.fill",
            tint: .accentColor,
            value: $value,
            range: 0...Double(maximum),
            step: 1
        )
        .accessibilityIdentifier("media-detail-progress-field")
    }
}

private struct ScoreEditorSection: View {
    @Binding var score: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Score", systemImage: "star.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(TrackingEditorPresentation.scoreText(score))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            StarRatingControl(score: $score)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

private struct StarRatingControl: View {
    @Binding var score: Double?

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        score = buttonScore(for: index)
                    } label: {
                        Image(systemName: TrackingEditorPresentation.starName(score: score, index: index))
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.yellow)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                    .accessibilityLabel("\(Int(buttonScore(for: index))) out of 10")
                    .accessibilityValue(
                        TrackingEditorPresentation.scoreButtonAccessibilityValue(
                            score: score,
                            buttonScore: buttonScore(for: index)
                        )
                    )
                    .accessibilityHint("Sets score")
                    .accessibilityIdentifier("media-detail-score-\(index * 2)-button")
                    .accessibilityAddTraits(score == buttonScore(for: index) ? .isSelected : [])
                }
            }
        }
        .accessibilityLabel("Score")
        .accessibilityValue(TrackingEditorPresentation.scoreText(score))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                score = TrackingEditorPresentation.scoreAfterAdjustment(score, direction: .increment)
            case .decrement:
                score = TrackingEditorPresentation.scoreAfterAdjustment(score, direction: .decrement)
            @unknown default:
                break
            }
        }
    }

    private func buttonScore(for index: Int) -> Double {
        Double(index * 2)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = clampedSteppedValue(value + step)
            case .decrement:
                value = clampedSteppedValue(value - step)
            @unknown default:
                break
            }
        }
    }

    private var normalizedValue: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    private func updateValue(locationY: CGFloat, height: CGFloat) {
        guard height > 0 else { return }
        let normalized = min(max(1 - (locationY / height), 0), 1)
        let rawValue = range.lowerBound + (range.upperBound - range.lowerBound) * normalized
        value = clampedSteppedValue(rawValue)
    }

    private func clampedSteppedValue(_ rawValue: Double) -> Double {
        guard step > 0 else {
            return min(max(rawValue, range.lowerBound), range.upperBound)
        }
        let stepped = (rawValue / step).rounded() * step
        return min(max(stepped, range.lowerBound), range.upperBound)
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

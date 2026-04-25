import SwiftUI

struct MediaRowView: View {
    let item: MediaSummary
    var onEditTracking: ((MediaMetadataChipPresentation.Kind) -> Void)?

    private var mediaTypeTitle: String {
        MediaType(rawValue: item.mediaType)?.title ?? item.mediaType.capitalized
    }

    private var mediaTypeIcon: String {
        MediaType(rawValue: item.mediaType)?.systemImage ?? "square.stack.fill"
    }

    private var posterURL: URL? {
        guard let string = item.item?.image else { return nil }
        return URL(string: string)
    }

    private var posterIdentifier: String {
        "library-card-poster-\(item.id)"
    }

    private var cardIdentifier: String {
        "library-card-\(item.id)"
    }

    private var titleIdentifier: String {
        "library-card-title-\(item.id)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            posterView

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .accessibilityIdentifier(titleIdentifier)

                    Label(mediaTypeTitle, systemImage: mediaTypeIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }

                HStack(spacing: 7) {
                    ForEach(MediaMetadataChipPresentation.makeChips(for: item), id: \.self) { chip in
                        if let onEditTracking {
                            Button {
                                onEditTracking(chip.kind)
                            } label: {
                                metadataChip(chip)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("library-card-\(chip.kind.accessibilityFragment)-button-\(item.id)")
                        } else {
                            metadataChip(chip)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.92))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(cardIdentifier)
    }

    @ViewBuilder
    private var posterView: some View {
        Group {
            if let posterURL {
                AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .empty:
                        posterPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .accessibilityIdentifier(posterIdentifier)
                    case .failure:
                        posterPlaceholder
                    @unknown default:
                        posterPlaceholder
                    }
                }
            } else {
                posterPlaceholder
            }
        }
        .frame(width: 94, height: 138)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .tertiarySystemGroupedBackground),
                            Color(uiColor: .secondarySystemGroupedBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(mediaTypeTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(12)
        }
        .accessibilityIdentifier(posterIdentifier)
    }

    private func metadataChip(_ chip: MediaMetadataChipPresentation) -> some View {
        HStack(spacing: 7) {
            Image(systemName: chip.systemImage)
                .font(.caption2.weight(.bold))

            Text(displayText(for: chip))
                .font(.caption.weight(.semibold))
        }
            .foregroundStyle(chip.foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(chip.backgroundColor)
            )
            .accessibilityLabel(chip.text)
    }

    private func displayText(for chip: MediaMetadataChipPresentation) -> String {
        guard chip.kind == .score else { return chip.text }
        return chip.text
            .replacingOccurrences(of: " / 10", with: "")
            .replacingOccurrences(of: "/10", with: "")
    }

}

struct MediaMetadataChipPresentation: Equatable, Hashable {
    enum Kind: Equatable, Hashable {
        case status
        case progress
        case score

        var accessibilityFragment: String {
            switch self {
            case .status:
                return "status"
            case .progress:
                return "progress"
            case .score:
                return "score"
            }
        }
    }

    enum Tone: Equatable, Hashable {
        case neutral
        case accent
        case positive
        case rating
        case subdued
    }

    let text: String
    let systemImage: String
    let tone: Tone
    let kind: Kind

    static func makeChips(for item: MediaSummary) -> [MediaMetadataChipPresentation] {
        var chips: [MediaMetadataChipPresentation] = []

        if let status = item.status {
            chips.append(Self.statusChip(for: status))
        }

        if MediaType(rawValue: item.mediaType) == .movie, let scoreLabel = item.scoreLabel {
            chips.append(
                .init(
                    text: scoreLabel,
                    systemImage: "star.fill",
                    tone: .rating,
                    kind: .score
                )
            )
        } else if let progressLabel = item.progressLabel {
            chips.append(
                .init(
                    text: progressLabel,
                    systemImage: "chart.bar.fill",
                    tone: .accent,
                    kind: .progress
                )
            )
        }

        return chips
    }

    private static func statusChip(for status: MediaSummary.Status) -> MediaMetadataChipPresentation {
        switch status {
        case .planning:
            return .init(text: status.title, systemImage: status.systemImage, tone: .neutral, kind: .status)
        case .inProgress:
            return .init(text: status.title, systemImage: status.systemImage, tone: .accent, kind: .status)
        case .paused:
            return .init(text: status.title, systemImage: status.systemImage, tone: .subdued, kind: .status)
        case .completed:
            return .init(text: status.title, systemImage: status.systemImage, tone: .positive, kind: .status)
        case .dropped:
            return .init(text: status.title, systemImage: status.systemImage, tone: .subdued, kind: .status)
        }
    }

    var backgroundColor: Color {
        switch tone {
        case .neutral:
            return Color(.secondarySystemBackground).opacity(0.92)
        case .accent:
            return Color.accentColor.opacity(0.12)
        case .positive:
            return Color.green.opacity(0.14)
        case .rating:
            return Color.orange.opacity(0.13)
        case .subdued:
            return Color(.tertiarySystemBackground).opacity(0.94)
        }
    }

    var foregroundColor: Color {
        switch tone {
        case .neutral, .subdued:
            return .secondary
        case .accent:
            return .accentColor
        case .positive:
            return Color.green
        case .rating:
            return Color.orange
        }
    }
}

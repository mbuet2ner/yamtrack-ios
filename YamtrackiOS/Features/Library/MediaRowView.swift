import SwiftUI

struct MediaRowView: View {
    let item: MediaSummary

    private var mediaTypeTitle: String {
        MediaType(rawValue: item.mediaType)?.title ?? item.mediaType.capitalized
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
        GlassSurface {
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

                        Text(mediaTypeTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        if let status = item.statusLabel {
                            metadataChip(systemImage: "circle.fill", text: status)
                        }

                        if let progressLabel = item.progressLabel {
                            metadataChip(systemImage: "chart.bar.fill", text: "Progress \(progressLabel)")
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(width: 92, height: 136)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.tertiarySystemBackground),
                            Color(.secondarySystemBackground).opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.18))
        }
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
    }

    private var posterPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.88, blue: 0.84),
                            Color(red: 0.80, green: 0.78, blue: 0.74)
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

    private func metadataChip(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.secondarySystemBackground).opacity(0.95))
            )
    }
}

import SwiftUI

struct MediaRowView: View {
    let item: MediaSummary

    var body: some View {
        GlassSurface {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)

                    Text(MediaType(rawValue: item.mediaType)?.title ?? item.mediaType.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let status = item.status {
                        Text(status.capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                if let progressLabel = item.progressLabel {
                    Text(progressLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

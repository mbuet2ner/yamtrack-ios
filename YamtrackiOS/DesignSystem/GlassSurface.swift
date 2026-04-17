import SwiftUI

struct FloatingActionPresentation: Equatable {
    let symbolName: String
    let diameter: CGFloat
    let bottomOffset: CGFloat

    static let addMedia = FloatingActionPresentation(
        symbolName: "plus",
        diameter: 48,
        bottomOffset: 15
    )
}

struct GlassSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .glassEffect(in: .rect(cornerRadius: Theme.cornerRadius))
    }
}

struct ContentSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(contentBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            }
    }

    private var contentBackground: some ShapeStyle {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
}

struct FloatingAddOrb: View {
    let action: () -> Void
    private let presentation = FloatingActionPresentation.addMedia

    var body: some View {
        Button(action: action) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: presentation.diameter, height: presentation.diameter)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        .accessibilityLabel("Add media")
    }
}

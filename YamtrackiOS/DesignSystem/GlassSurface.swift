import SwiftUI

struct FloatingActionPresentation: Equatable {
    let symbolName: String
    let diameter: CGFloat
    let hitTargetDiameter: CGFloat

    static let addMedia = FloatingActionPresentation(
        symbolName: "plus",
        diameter: 64,
        hitTargetDiameter: 76
    )
}

struct BottomChromePresentation: Equatable {
    let horizontalPadding: CGFloat
    let bottomPadding: CGFloat
    let spacing: CGFloat

    static let floatingAction = BottomChromePresentation(
        horizontalPadding: Theme.screenPadding + (FloatingActionPresentation.addMedia.diameter / 2) - 8,
        bottomPadding: Theme.contentSpacing,
        spacing: Theme.contentSpacing
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
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: presentation.diameter, height: presentation.diameter)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .frame(width: presentation.hitTargetDiameter, height: presentation.hitTargetDiameter)
        .contentShape(Circle())
        .accessibilityLabel("Add media")
        .accessibilityIdentifier("library-add-media-button")
    }
}

struct BottomChrome<Content: View>: View {
    private let presentation: BottomChromePresentation
    private let content: Content

    init(
        presentation: BottomChromePresentation = .floatingAction,
        @ViewBuilder content: () -> Content
    ) {
        self.presentation = presentation
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer(spacing: presentation.spacing) {
            HStack(spacing: presentation.spacing) {
                content
            }
            .padding(.horizontal, presentation.horizontalPadding)
            .padding(.bottom, presentation.bottomPadding)
        }
    }
}

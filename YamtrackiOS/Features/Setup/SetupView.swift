import SwiftUI

struct SetupView: View {
    private let onDismiss: (() -> Void)?
    private let onConnectionUpdated: (() -> Void)?
    @State private var viewModel: SetupViewModel

    init(
        session: SessionController,
        onDismiss: (() -> Void)? = nil,
        onConnectionUpdated: (() -> Void)? = nil
    ) {
        self.onDismiss = onDismiss
        self.onConnectionUpdated = onConnectionUpdated
        _viewModel = State(initialValue: SetupViewModel(session: session))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                credentialsCard
                connectAction

                if viewModel.canDisconnect {
                    disconnectCard
                }

                if let errorMessage = viewModel.errorMessage {
                    errorBanner(message: errorMessage)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 120)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("")
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbar {
            if let onDismiss, viewModel.canDisconnect {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(navigationTitle)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(viewModel.canDisconnect ? "Manage the Yamtrack server this device uses." : "Connect this device to your Yamtrack library.")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if let onDismiss, viewModel.canDisconnect {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .glassEffect(.regular.interactive(), in: .capsule)
                } else {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 68, height: 68)
                        .glassEffect(.regular.tint(Color.accentColor.opacity(0.12)), in: .circle)
                }
            }

        }
    }

    private var credentialsCard: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 16) {
                Label("Server", systemImage: "server.rack")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)

                inputField(title: "Server URL", systemImage: "network") {
                    TextField("Server URL", text: $viewModel.baseURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                        .keyboardType(.URL)
                }

                inputField(title: "API Token", systemImage: "key.fill") {
                    SecureField("API Token", text: $viewModel.token)
                        .textContentType(.password)
                }
            }
        }
    }

    private func inputField<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                content()
                    .font(.headline.weight(.medium))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 68)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private var connectAction: some View {
        Button {
            Task {
                if await viewModel.connect() {
                    onConnectionUpdated?()
                }
            }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isConnecting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                }

                Text(viewModel.isConnecting ? "Connecting" : "Connect")
            }
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.accentColor.opacity(0.22), radius: 22, x: 0, y: 12)
        .disabled(viewModel.isConnecting)
        .accessibilityIdentifier("setup-connect-button")
    }

    private var disconnectCard: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 14) {
                Label("Disconnect this device", systemImage: "xmark.circle.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.red)

                Text("Remove the saved Yamtrack connection and return to the connect flow.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Button("Disconnect", role: .destructive) {
                    viewModel.disconnect()
                }
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .glassEffect(.regular.tint(Color.red.opacity(0.12)).interactive(), in: .capsule)
            }
        }
    }

    private func errorBanner(message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.red)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(Color.red.opacity(0.08)), in: .rect(cornerRadius: 24))
    }

    private var navigationTitle: String {
        onDismiss != nil && viewModel.canDisconnect ? "Connection" : "Connect"
    }
}

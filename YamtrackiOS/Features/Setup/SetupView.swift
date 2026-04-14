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
        Form {
            Section("Server") {
                TextField("Server URL", text: $viewModel.baseURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.URL)

                SecureField("API Token", text: $viewModel.token)
                    .textContentType(.password)
            }

            Section {
                Button("Connect") {
                    Task {
                        if await viewModel.connect() {
                            onConnectionUpdated?()
                        }
                    }
                }
                .disabled(viewModel.isConnecting)
            }

            if viewModel.canDisconnect {
                Section {
                    Button("Disconnect", role: .destructive) {
                        viewModel.disconnect()
                    }
                } footer: {
                    Text("Remove your saved Yamtrack connection from this device and return to the connect flow.")
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(navigationTitle)
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

    private var navigationTitle: String {
        if onDismiss != nil, viewModel.canDisconnect {
            return "Connection"
        }

        return "Connect"
    }
}

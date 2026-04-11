import SwiftUI

struct SetupView: View {
    @State private var viewModel: SetupViewModel

    init(session: SessionController) {
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
                        await viewModel.connect()
                    }
                }
                .disabled(viewModel.isConnecting)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Connect")
    }
}

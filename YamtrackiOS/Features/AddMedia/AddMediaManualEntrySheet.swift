import SwiftUI

struct AddMediaManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddMediaViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $viewModel.manualTitle)
                        .accessibilityIdentifier("add-media-manual-title-field")

                    TextField("Image URL", text: $viewModel.manualImageURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Status", selection: $viewModel.manualStatus) {
                        ForEach(MediaSummary.Status.allCases, id: \.self) { status in
                            Text(status.title).tag(status)
                        }
                    }

                    HStack {
                        TextField("Progress", text: $viewModel.manualProgress)
                            .keyboardType(.numberPad)

                        TextField("Score", text: $viewModel.manualScore)
                            .keyboardType(.decimalPad)
                    }

                    TextField("Notes", text: $viewModel.manualNotes, axis: .vertical)
                        .lineLimit(3...5)
                } header: {
                    Text(viewModel.selectedType?.singularTitle ?? "Media")
                } footer: {
                    Text("Create a custom entry with your own details.")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .accessibilityIdentifier("add-media-manual-sheet")
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.dismissManualSheet()
                        dismiss()
                    }
                    .disabled(viewModel.isCreating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            do {
                                try await viewModel.createManualMedia()
                            } catch {
                            }
                        }
                    } label: {
                        if viewModel.isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .accessibilityIdentifier("add-media-manual-submit-button")
                    .disabled(viewModel.isCreating || viewModel.selectedType == nil || viewModel.manualTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

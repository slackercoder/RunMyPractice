import SwiftUI
import SwiftData

/// Sheet for adding a player/athlete to the roster (Functional Spec §5.5).
/// A single coach-assigned label field — no PII (Technical Spec §2).
struct CreatePlayerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = PlayerCreateViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    TextField("Label (e.g. \"Skip A\", \"Lead\", \"Player 1\")", text: $viewModel.name)
                        .submitLabel(.done)
                        .onSubmit(save)
                } header: {
                    Text("Add Player")
                } footer: {
                    if let message = viewModel.validationMessage {
                        Text(message)
                            .foregroundStyle(.red)
                    } else {
                        Text("Use any label that helps you run drills — real names are never stored.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!viewModel.isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard viewModel.save(into: modelContext) != nil else { return }
        dismiss()
    }
}

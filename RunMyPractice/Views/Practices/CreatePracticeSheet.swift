import SwiftUI
import SwiftData

/// Sheet for creating a new practice (Functional Spec §6 create flow).
/// MVP: title only — the full activity/drill editor arrives in M3.
struct CreatePracticeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = PracticeCreateViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    TextField("Practice title (e.g. \"Curling Fundamentals\")", text: $viewModel.title)
                        .submitLabel(.done)
                        .onSubmit(save)
                } header: {
                    Text("New Practice")
                } footer: {
                    if let message = viewModel.validationMessage {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Practice")
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

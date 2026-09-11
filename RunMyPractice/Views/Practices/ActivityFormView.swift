import SwiftUI
import SwiftData

/// Add/edit form for a practice activity (M3). Drafts the field values in
/// `ActivityFormViewModel` and applies them to the model on Save; for a
/// just-added activity, Cancel removes the placeholder.
struct ActivityFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State var viewModel: ActivityFormViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Title (e.g. \"Warm-up\", \"End-Game Scenarios\")", text: $viewModel.title)
                        .onSubmit(save)
                    TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                }

                Section("Time") {
                    TextField("Minutes", value: $viewModel.minutes, format: .number)
                        .keyboardType(.numberPad)
                    Stepper("Time: \(viewModel.minutes) min", value: $viewModel.minutes, in: 1...600, step: 5)
                }

                if let message = viewModel.validationMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.isCreating ? "New Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!viewModel.isValid)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        viewModel.save()
        dismiss()
    }

    private func cancel() {
        viewModel.cancel(in: modelContext)
        dismiss()
    }
}

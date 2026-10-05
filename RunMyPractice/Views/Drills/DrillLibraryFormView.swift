import SwiftUI
import SwiftData

/// Add/edit form for a drill *library* entry (v0.12.0): the same fields as
/// the in-practice drill form (title, description, notes, scoring
/// configuration, coach-only visibility), stored against the standalone
/// `DrillLibrary` record.
///
/// Library drills are the reusable pool that the "Add Drill" picker in the
/// practice editor draws from; picking one copies it into the activity, so
/// this form edits the *template*, never a drill inside a practice.
struct DrillLibraryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State var viewModel: DrillLibraryFormViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("Drill") {
                    TextField("Title (e.g. \"Draw to the Button\")", text: $viewModel.title)
                        .onSubmit(save)
                    TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                    TextField("Notes (optional — e.g. setup, cues, what to watch for)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Scoring") {
                    Toggle("Scored drill", isOn: $viewModel.isScored)
                    if viewModel.isScored {
                        TextField("Max points (e.g. 10)", text: $viewModel.maxPointsText)
                            .keyboardType(.numberPad)
                        TextField("Point step (e.g. 2)", text: $viewModel.pointStepText)
                            .keyboardType(.numberPad)
                        if !viewModel.scoreOptionsPreview.isEmpty {
                            Text("Choices: \(viewModel.scoreOptionsPreview)")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Unscored drills show as a check-off during practice.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Visibility") {
                    Toggle("Coach-only drill", isOn: $viewModel.isCoachDrill)
                    Text("Coach-only drills are hidden from athlete-facing views.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let message = viewModel.validationMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .sheetSurface()
            .navigationTitle(viewModel.isCreating ? "New Drill" : "Edit Drill")
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
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .sheetBackdrop()
        .presentationDetents([.large])
    }

    private func save() {
        viewModel.save()
        // The library form is a dead-end sheet (there is no later "Done"
        // step), so the explicit save here is the only persistence.
        try? modelContext.save()
        dismiss()
    }

    private func cancel() {
        viewModel.cancel(in: modelContext)
        dismiss()
    }
}

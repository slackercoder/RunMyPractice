import SwiftUI
import SwiftData

/// Add/edit form for a drill (M3): title, description, the scoring
/// configuration (scored? max points, step — with a live choice-matrix
/// preview per Technical Spec §5), and coach-only visibility.
struct DrillFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State var viewModel: DrillFormViewModel

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
        dismiss()
    }

    private func cancel() {
        viewModel.cancel(in: modelContext)
        dismiss()
    }
}

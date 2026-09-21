import SwiftUI
import SwiftData

/// Create-a-player form (roster, Functional Spec §5.5).
///
/// Used from the Players tab and from the execute screen's participant sheet
/// (where `session != nil` — the new player is enrolled in that session as a
/// solo participant on Save, per `PlayerFormViewModel`).
struct PlayerFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Player.playerName) private var players: [Player]
    @State private var viewModel: PlayerFormViewModel

    init(session: PracticeSession? = nil) {
        _viewModel = State(initialValue: PlayerFormViewModel(session: session))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("Player") {
                    TextField("Label (e.g. \"Skip A\", \"Lead\")", text: $viewModel.name)
                        .autocorrectionDisabled()
                        .onSubmit(save)
                }

                Section {
                    Text("Zero PII by design — use the label you call them in practice, not a real name.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if viewModel.session != nil {
                        Text("The new player will be added to the current session as a participant.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = viewModel.validationMessage, !viewModel.name.isEmpty {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .sheetSurface()
            .navigationTitle("New Player")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.existingPlayerNames = players.map(\.playerName)
            }
            .onChange(of: players) { _, newPlayers in
                viewModel.existingPlayerNames = newPlayers.map(\.playerName)
            }
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
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .sheetBackdrop()
        .presentationDetents([.large])
    }

    private func save() {
        viewModel.save(in: modelContext)
        dismiss()
    }
}

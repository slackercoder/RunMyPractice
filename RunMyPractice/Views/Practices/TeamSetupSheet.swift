import SwiftUI
import SwiftData

/// Participant setup sheet for the execute screen (M4).
///
/// Pick who runs the practice — entirely from here, no need to leave the
/// practice screen:
/// - **Teams** — named groups (free-form, e.g. "Team 1"), deletable in place.
/// - **Players** — solo participants; the app provisions each as a background
///   "team of 1" on Save (Technical Spec §4). Players can be created,
///   selected, and deleted right from this sheet.
///
/// Cancel rolls back in-place changes (e.g. a team removed this visit) and
/// discards the draft.
struct TeamSetupSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State var viewModel: TeamSetupViewModel
    @State private var showingPlayerForm = false
    @State private var pendingDeletePlayer: Player?
    @Query(sort: \Player.playerName) private var players: [Player]

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("Teams") {
                    ForEach(viewModel.namedTeams) { sessionTeam in
                        HStack {
                            Label(sessionTeam.team?.teamName ?? "—", systemImage: "person.2")
                            Spacer()
                            Button {
                                viewModel.removeNamedTeam(sessionTeam, in: modelContext)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .accessibilityLabel("Remove team")
                        }
                    }

                    HStack {
                        TextField("Add team (e.g. \"Team 1\")", text: $viewModel.newTeamName)
                            .onSubmit(save)
                        Button("Add") {
                            save()
                        }
                        .disabled(!viewModel.canAddTeam)
                    }

                    if viewModel.namedTeams.isEmpty && viewModel.soloTeams.isEmpty {
                        Text("No participants yet — add a team or select players below.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Players (run as a team of 1)") {
                    if players.isEmpty {
                        Text("No players yet — create one below, then it shows here for selection.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(players) { player in
                        let selected = viewModel.isPlayerSelected(player)
                        Button {
                            viewModel.togglePlayer(player)
                        } label: {
                            HStack {
                                Label(player.playerName, systemImage: selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected ? Color.accentColor : .primary)
                                Spacer()
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDeletePlayer = player
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        showingPlayerForm = true
                    } label: {
                        Label("New Player", systemImage: "person.badge.plus")
                    }
                }

                if let message = viewModel.validationMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Participants")
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
        .presentationDetents([.large])
        .sheet(
            isPresented: $showingPlayerForm,
            onDismiss: {
                // Pick up any player added in the nested sheet.
                viewModel.refreshSelections()
            }
        ) {
            PlayerFormView(session: viewModel.session)
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { pendingDeletePlayer != nil },
                set: { if !$0 { pendingDeletePlayer = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Player", role: .destructive) {
                if let player = pendingDeletePlayer {
                    viewModel.deletePlayer(player, in: modelContext)
                }
            }
        } message: {
            if let player = pendingDeletePlayer {
                Text("This removes \"\(player.playerName)\" from the roster, their team of 1, and any session participant entries.")
            }
        }
    }

    private var deleteDialogTitle: String {
        if let player = pendingDeletePlayer {
            return "Delete \"\(player.playerName)\"?"
        }
        return "Delete Player?"
    }

    private func save() {
        viewModel.save(in: modelContext)
        dismiss()
    }

    private func cancel() {
        // Restores any named team removed during this visit; the rest of the
        // draft (text field, player toggles) never touched the models.
        modelContext.rollback()
        dismiss()
    }
}

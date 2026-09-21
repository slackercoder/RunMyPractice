import SwiftUI
import SwiftData

/// Participant setup sheet for the execute screen (M4, v0.5.0).
///
/// Pick who runs the practice — entirely from here, no need to leave the
/// practice screen:
/// - **Teams** — reusable roster teams, selected with a checkmark; new team
///   names are added to (or matched against) the roster on Save. Orphaned
///   session team rows (whose roster team was deleted) are shown with a
///   remove button.
/// - **Players** — solo participants, each running as a values-only "team of
///   1" (Technical Spec §4). Players can be created, selected, and deleted
///   right from this sheet.
///
/// Cancel rolls back in-place changes and discards the draft; Save upserts
/// the session's participant rows (re-freezing current names/labels).
struct TeamSetupSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State var viewModel: TeamSetupViewModel
    @State private var showingPlayerForm = false
    @State private var pendingDeletePlayer: Player?
    @Query(sort: \Player.playerName) private var players: [Player]
    @Query(sort: \Team.teamName) private var teams: [Team]

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("Teams") {
                    if teams.isEmpty {
                        Text("No teams yet — add one below, or select players below.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(teams) { team in
                        let selected = viewModel.isTeamSelected(team)
                        Button {
                            viewModel.toggleTeam(team)
                        } label: {
                            HStack {
                                Label(team.teamName, systemImage: selected ? "checkmark.circle.fill" : "person.2")
                                    .foregroundStyle(selected ? Color.accentColor : .primary)
                                Spacer()
                            }
                        }
                    }

                    // In-session team rows whose roster team no longer exists
                    // (or has no source): shown as-is, removable in place.
                    ForEach(viewModel.orphanedTeams(teams: teams)) { sessionTeam in
                        HStack {
                            Label(sessionTeam.teamName, systemImage: "person.2")
                            Spacer()
                            Button {
                                viewModel.removeSessionTeam(sessionTeam, in: modelContext)
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

                    if teams.isEmpty && viewModel.namedTeams.isEmpty && viewModel.soloTeams.isEmpty {
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
            .sheetSurface()
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
        .sheetBackdrop()
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
                Text("This removes \"\(player.playerName)\" from the roster and from this session. Recorded runs keep their frozen copy of the player.")
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

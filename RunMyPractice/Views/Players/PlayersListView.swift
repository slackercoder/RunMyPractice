import SwiftUI
import SwiftData

/// Player/athlete roster (Functional Spec §5.5): list, add, remove.
///
/// Zero PII by design (Technical Spec §2): these are coach-assigned labels
/// (e.g. "Skip A", "Lead"), not real names. Teams are assembled at
/// execution time (M4), not here.
///
/// Standings (v0.7.0): each row shows the player's current points total —
/// every point a team they were on scored, plus solo scores — counted from
/// recorded runs after the latest reset. Totals are computed, never stored,
/// and "Reset Standings" appends a one-way marker, so monthly leagues work:
/// reset, run a month, award the prize, reset again. Past runs are never
/// touched by a reset and stay reviewable in the Runs tab.
struct PlayersListView: View {
    @Query(sort: \Player.playerName)
    private var players: [Player]

    /// Every recorded run (v0.7.0) — standings are computed from them.
    /// Session counts are small on-device, so the in-memory tally is fine.
    @Query private var sessions: [PracticeSession]

    /// Standings resets, oldest first (v0.7.0); only the latest matters.
    @Query(sort: \StandingsReset.date)
    private var resets: [StandingsReset]

    @Environment(\.modelContext) private var modelContext
    @State private var showingCreateSheet = false
    @State private var showingResetSheet = false
    @State private var pendingDelete: Player?
    @State private var sort: SortOption = .name

    enum SortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case points = "Points"
        var id: Self { self }
    }

    /// The latest reset marker, if any (v0.7.0).
    private var lastReset: StandingsReset? {
        resets.last
    }

    private func points(for player: Player) -> Int {
        player.totalPoints(in: sessions, since: lastReset?.date)
    }

    private var sortedPlayers: [Player] {
        switch sort {
        case .name:
            return players
        case .points:
            // Leaderboard: points descending, label as the tiebreaker.
            return players.sorted {
                let a = points(for: $0), b = points(for: $1)
                return a != b ? a > b : $0.playerName < $1.playerName
            }
        }
    }

    private var playersWithPoints: Int {
        players.filter { points(for: $0) > 0 }.count
    }

    private var currentTotalPoints: Int {
        players.reduce(0) { $0 + points(for: $1) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if players.isEmpty {
                    ContentUnavailableView {
                        Label("No Players Yet", systemImage: "person.2")
                    } description: {
                        Text("Add players with the labels you use in practice — no real names needed.")
                    } actions: {
                        Button("Add Player") {
                            showingCreateSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(sortedPlayers) { player in
                                playerRow(player)
                            }
                            .confirmationDialog(
                                "Delete this player?",
                                isPresented: Binding(
                                    get: { pendingDelete != nil },
                                    set: { if !$0 { pendingDelete = nil } }
                                ),
                                titleVisibility: .visible
                            ) {
                                Button("Delete \(pendingDelete?.playerName ?? "")", role: .destructive) {
                                    if let player = pendingDelete {
                                        player.delete(in: modelContext)
                                        try? modelContext.save()
                                    }
                                    pendingDelete = nil
                                }
                                Button("Cancel", role: .cancel) {
                                    pendingDelete = nil
                                }
                            }
                        } header: {
                            if let lastReset {
                                Text("Standings · runs after \(lastReset.date.formatted(date: .abbreviated, time: .omitted))")
                            } else {
                                Text("Standings")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Players")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Sort", selection: $sort) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("Add Player", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingResetSheet = true
                    } label: {
                        Label("Reset Standings", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreatePlayerSheet()
            }
            .sheet(isPresented: $showingResetSheet) {
                ResetStandingsSheet(
                    playersWithPoints: playersWithPoints,
                    currentTotalPoints: currentTotalPoints
                )
            }
        }
    }

    private func playerRow(_ player: Player) -> some View {
        HStack(spacing: 6) {
            Text(player.playerName)
            Spacer()
            let points = points(for: player)
            Text("\(points) pts")
                .monospacedDigit()
                .foregroundStyle(points > 0 ? Color.primary : Color.secondary)
        }
        .swipeActions {
            Button(role: .destructive) {
                pendingDelete = player
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// Confirmation (plus optional note) for resetting the standings (v0.7.0).
///
/// A reset appends a one-way marker — it does not delete anything. Recorded
/// runs stay intact and reviewable; totals are simply re-counted from runs
/// after the latest marker.
private struct ResetStandingsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var playersWithPoints: Int
    var currentTotalPoints: Int

    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Players with points", value: "\(playersWithPoints)")
                    LabeledContent("Points cleared", value: "\(currentTotalPoints)")
                }
                Section {
                    Text("Clears the current totals for everyone so the next period starts at zero. Recorded runs are untouched — they can still be reviewed, they just stop counting.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Note (optional)") {
                    TextField("e.g. \"June league — prizes awarded\"", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section {
                    Button("Reset Standings", role: .destructive) {
                        reset()
                    }
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Reset Standings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func reset() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(
            StandingsReset(date: Date(), note: trimmed.isEmpty ? nil : trimmed)
        )
        try? modelContext.save()
        dismiss()
    }
}

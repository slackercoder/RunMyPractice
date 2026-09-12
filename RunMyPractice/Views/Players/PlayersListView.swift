import SwiftUI
import SwiftData

/// Player/athlete roster (Functional Spec §5.5): list, add, remove.
///
/// Zero PII by design (Technical Spec §2): these are coach-assigned labels
/// (e.g. "Skip A", "Lead"), not real names. Teams are assembled at
/// execution time (M4), not here.
struct PlayersListView: View {
    @Query(sort: \Player.playerName)
    private var players: [Player]

    @Environment(\.modelContext) private var modelContext
    @State private var showingCreateSheet = false
    @State private var pendingDelete: Player?

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
                        ForEach(players) { player in
                            Text(player.playerName)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        pendingDelete = player
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
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
                    }
                }
            }
            .navigationTitle("Players")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("Add Player", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreatePlayerSheet()
            }
        }
    }

}

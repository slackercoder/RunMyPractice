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
                        }
                        .onDelete(perform: delete)
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

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(players[index])
        }
        try? modelContext.save()
    }
}

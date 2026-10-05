import SwiftUI
import SwiftData

/// Home screen (Functional Spec §5.2): the list of available practices with
/// search by title and create-new. "Create" opens the full practice editor
/// (M3) with a blank draft; live execution of a practice arrives in M4.
struct PracticesHomeView: View {
    @Query(sort: \Practice.createDate, order: .reverse)
    private var practices: [Practice]

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    @State private var searchText = ""
    @State private var newPracticeDraft: Practice?
    @State private var practiceToDelete: Practice?

    private var filteredPractices: [Practice] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return practices }
        return practices.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if practices.isEmpty {
                    ContentUnavailableView {
                        Label("No Practices Yet", systemImage: "target")
                    } description: {
                        Text("Create your first practice to get started.")
                    } actions: {
                        Button("Create Practice") {
                            startNewPractice()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if filteredPractices.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    practiceList
                }
            }
            .sheetSurface()
            .navigationTitle("Practices")
            // Registered on the Group, not the List: the List only exists when
            // the query is non-empty, so a refetch that flips the branch would
            // unregister the destination and silently pop any pushed practice
            // (v0.6.1).
            .navigationDestination(for: Practice.self) { practice in
                PracticeDetailView(practice: practice)
            }
            .searchable(text: $searchText, prompt: "Search practices")
            .safeAreaInset(edge: .top) {
                syncStatusView
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        syncService.syncNow()
                    } label: {
                        Label("Sync", systemImage: syncStatusIcon)
                    }
                    .disabled(syncService.isSyncing)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startNewPractice()
                    } label: {
                        Label("New Practice", systemImage: "plus")
                    }
                }
            }
            .fullScreenCover(item: $newPracticeDraft) { practice in
                PracticeEditorView(practice: practice)
            }
        }
    }

    /// One-line sync status under the nav bar (M6b): shown only when there
    /// is something to report — a pending/never-synced dataset, an in-flight
    /// sync, the last success, or a failure with its reason.
    @ViewBuilder
    private var syncStatusView: some View {
        if let description = syncService.statusDescription {
            HStack(spacing: 8) {
                Image(systemName: syncStatusIcon)
                    .foregroundStyle(syncStatusColor)
                Text(description)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .font(.footnote)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.bar)
        }
    }

    private var syncStatusIcon: String {
        if syncService.isSyncing { return "arrow.triangle.2.circlepath" }
        switch syncService.status {
        case .synced: return "checkmark.icloud"
        case .failed: return "exclamationmark.icloud"
        default: return "icloud"
        }
    }

    private var syncStatusColor: Color {
        switch syncService.status {
        case .failed: return .red
        case .synced: return .green
        default: return .secondary
        }
    }

    private var practiceList: some View {
        List(filteredPractices) { practice in
            NavigationLink(value: practice) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(practice.title)
                        .font(.headline)
                    Text(subtitle(for: practice))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .swipeActions(edge: .trailing) {
                // v0.13.0: delete from the list — confirmation first, since a
                // practice is a whole template.
                Button(role: .destructive) {
                    practiceToDelete = practice
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Delete this practice?",
            isPresented: Binding(
                get: { practiceToDelete != nil },
                set: { if !$0 { practiceToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let practice = practiceToDelete else { return }
                // Delete activities explicitly (drills cascade). Recorded runs
                // are safe — sessions keep their own frozen plan snapshot, and
                // the template's activities/drills are this coach's own copies.
                for activity in practice.activities {
                    modelContext.delete(activity)
                }
                modelContext.delete(practice)
                try? modelContext.save()
            }
        } message: {
            if let practice = practiceToDelete {
                Text("This removes \"\(practice.title)\" and its activities. Recorded runs are kept — each keeps a frozen copy of the plan as it was run.")
            }
        }
    }

    private func subtitle(for practice: Practice) -> String {
        let count = practice.orderedActivities.count
        let activityText = count == 1 ? "1 activity" : "\(count) activities"
        guard !practice.orderedActivities.isEmpty else { return activityText }
        return "\(activityText) · \(practice.totalTimeInMinutes) min"
    }

    /// Creates a blank practice (inserted but unsaved) and opens the editor
    /// with it. Cancel in the editor rolls back the draft; Done saves it.
    private func startNewPractice() {
        let practice = Practice(title: "New Practice")
        modelContext.insert(practice)
        newPracticeDraft = practice
    }
}

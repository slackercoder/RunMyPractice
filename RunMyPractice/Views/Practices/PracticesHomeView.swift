import SwiftUI
import SwiftData

/// Home screen (Functional Spec §5.2): the list of available practices with
/// search by title and create-new. "Create" opens the full practice editor
/// (M3) with a blank draft; live execution of a practice arrives in M4.
struct PracticesHomeView: View {
    @Query(sort: \Practice.createDate, order: .reverse)
    private var practices: [Practice]

    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var newPracticeDraft: Practice?

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
            .toolbar {
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

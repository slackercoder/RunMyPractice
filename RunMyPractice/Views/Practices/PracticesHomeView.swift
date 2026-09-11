import SwiftUI
import SwiftData

/// Home screen (Functional Spec §5.2): the list of available practices with
/// search by title and create-new. Tapping a practice opens its detail view
/// (M2); live execution of a practice arrives in M4.
struct PracticesHomeView: View {
    @Query(sort: \Practice.createDate, order: .reverse)
    private var practices: [Practice]

    @State private var searchText = ""
    @State private var showingCreateSheet = false

    private var filteredPractices: [Practice] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return practices }
        return practices.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if practices.isEmpty {
                    ContentUnavailableView {
                        Label("No Practices Yet", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Create your first practice to get started.")
                    } actions: {
                        Button("Create Practice") {
                            showingCreateSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if filteredPractices.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    practiceList
                }
            }
            .navigationTitle("Practices")
            .searchable(text: $searchText, prompt: "Search practices")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("New Practice", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreatePracticeSheet()
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
        .navigationDestination(for: Practice.self) { practice in
            PracticeDetailView(practice: practice)
        }
    }

    private func subtitle(for practice: Practice) -> String {
        let count = practice.orderedActivities.count
        let activityText = count == 1 ? "1 activity" : "\(count) activities"
        guard !practice.orderedActivities.isEmpty else { return activityText }
        return "\(activityText) · \(practice.totalTimeInMinutes) min"
    }
}

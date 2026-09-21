import SwiftUI
import SwiftData

/// Run history (v0.6.0): every recorded practice run, newest first.
///
/// Each `PracticeSession` is a self-contained run record (v0.5.0): the plan
/// as it was run, the participants as they were frozen, and the results.
/// Finished runs (`completedDate != nil`) are reviewable and deletable;
/// in-progress runs keep their "resume" behavior from the practice detail
/// screen — deleting one here also un-resumes it.
struct RunsListView: View {
    @Query(sort: \PracticeSession.createDate, order: .reverse)
    private var sessions: [PracticeSession]

    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var pendingDelete: PracticeSession?

    private var filteredSessions: [PracticeSession] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return sessions }
        return sessions.filter { session in
            let title = session.practiceTitle ?? session.practice?.title ?? ""
            if title.localizedCaseInsensitiveContains(searchText) { return true }
            return session.sessionTeams.contains {
                $0.teamName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No Runs Yet", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Execute a practice to record a run you can review here.")
                    }
                } else if filteredSessions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredSessions) { session in
                        NavigationLink(value: session) {
                            runRow(session)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                pendingDelete = session
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .sheetSurface()
            .navigationTitle("Runs")
            .searchable(text: $searchText, prompt: "Search runs by practice or participant")
            .navigationDestination(for: PracticeSession.self) { session in
                RunReviewView(session: session)
            }
            .confirmationDialog(
                "Delete this run?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Run", role: .destructive) {
                    if let pendingDelete {
                        modelContext.delete(pendingDelete)
                        try? modelContext.save()
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("This removes the recorded teams, check-offs, and scores. The practice itself is kept.")
            }
        }
    }

    private func runRow(_ session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(session.practiceTitle ?? session.practice?.title ?? "Untitled Practice")
                    .font(.headline)
                    .lineLimit(1)
                if session.completedDate == nil {
                    Text("in progress")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.25), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            Text(
                "\(session.createDate.formatted(date: .abbreviated, time: .shortened)) · "
                + "\(session.sessionTeams.count) participants"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Text(resultsSummary(session))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// "5 check-offs · 32 pts" — only non-zero parts; a run with no results
    /// yet reads "no results yet".
    private func resultsSummary(_ session: PracticeSession) -> String {
        let checkOffs = session.acknowledgements.filter(\.isAcknowledged).count
        let points = session.sessionTeams.reduce(0) { $0 + $1.scores.reduce(0) { $0 + $1.score } }
        var parts: [String] = []
        if checkOffs > 0 { parts.append("\(checkOffs) check-offs") }
        if points > 0 { parts.append("\(points) pts") }
        return parts.isEmpty ? "no results yet" : parts.joined(separator: " · ")
    }
}

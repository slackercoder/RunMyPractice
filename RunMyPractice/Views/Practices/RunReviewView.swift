import SwiftUI
import SwiftData

/// Read-only review of one recorded practice run (v0.6.0).
///
/// Everything shown comes from the session's self-contained record (v0.5.0):
/// the frozen plan, the frozen participant snapshots, the check-offs, and the
/// scores — plus the coach notes captured on each drill. Nothing here writes:
/// a review is a review, and the run it describes is history.
///
/// Presented as a pushed destination (Runs tab, or a practice's Past Runs).
/// Deliberately has NO NavigationStack of its own: a nested stack inside a
/// pushed view can clobber the outer stack's state and pop the screen back
/// instantly (v0.6.1).
struct RunReviewView: View {
    var session: PracticeSession

    private var participants: [PracticeSessionTeam] {
        session.sessionTeams
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: session.createDate.formatted(date: .abbreviated, time: .shortened))
                LabeledContent(
                    "Completed",
                    value: session.completedDate?.formatted(date: .abbreviated, time: .shortened) ?? "In progress"
                )
                LabeledContent("Participants", value: "\(participants.count)")
            }

            if participants.isEmpty {
                Section("Participants") {
                    Text("No participants were recorded for this run.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Participants") {
                    ForEach(participants) { participant in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(participant.teamName)
                                .font(.headline)
                            if !participant.playerLabels.isEmpty {
                                Text(participant.playerLabels.joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            ForEach(session.orderedActivities) { activity in
                Section("\(activity.title) · \(activity.timeAllottedInMinutes) min") {
                    ForEach(activity.orderedDrills) { drill in
                        drillRow(drill)
                    }
                }
            }
        }
        .sheetSurface()
        .navigationTitle(session.practiceTitle ?? session.practice?.title ?? "Run Review")
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .sheetBackdrop()
    }

    // MARK: - Drills

    private func drillRow(_ drill: Drill) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: drill.isScored ? "star.fill" : "checkmark.circle")
                    .foregroundStyle(drill.isScored ? Color.yellow : .green)
                Text(drill.title)
                    .font(.headline)
                if drill.isCoachDrill {
                    Text("coach")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                Text(resultText(drill))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let description = drill.drillDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let notes = drill.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // The coach's field notes as recorded during the run (v0.9.1).
            if let runNotes = drill.runNotes, !runNotes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(runNotes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if drill.isScored {
                ForEach(participants) { participant in
                    HStack {
                        Text(participant.teamName)
                            .font(.subheadline)
                        Spacer()
                        Text(participantScoreText(drill, participant: participant))
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// Scored: the per-participant total, or "—". Unscored: "Done" if the
    /// check-off exists, else "—". (Check-offs are per-drill, not per
    /// participant — a drill is either done for the group or it isn't.)
    private func resultText(_ drill: Drill) -> String {
        if drill.isScored {
            let total = participants.reduce(0) { $0 + (score(for: drill, participant: $1) ?? 0) }
            return participants.isEmpty || total == 0 ? "—" : "\(total) pts"
        }
        return session.acknowledgements.contains { $0.drill?.id == drill.id && $0.isAcknowledged }
            ? "Done"
            : "—"
    }

    private func score(for drill: Drill, participant: PracticeSessionTeam) -> Int? {
        participant.scores.first { $0.drill?.id == drill.id }?.score
    }

    private func participantScoreText(_ drill: Drill, participant: PracticeSessionTeam) -> String {
        score(for: drill, participant: participant).map { "\($0) pts" } ?? "—"
    }
}

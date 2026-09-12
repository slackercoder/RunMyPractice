import SwiftUI
import SwiftData

/// The practice execution screen (Functional Spec §6 "Execute Practice Flow", M4) —
/// the full view for running a practice session on the day.
///
/// The coach can:
/// - assign participants (TeamSetupSheet: named teams + solo players, the latter
///   provisioned as background "teams of 1" per Technical Spec §4),
/// - run an activity countdown timer,
/// - check off unscored drills (`DrillAcknowledgement`, session-scoped),
/// - score scored drills per participant (`TeamScore` from the drill's choice
///   matrix, Technical Spec §5),
/// - finish (keeps the session record) or discard it.
///
/// All interactions write to the live `PracticeSession` and save immediately
/// (the local container is the source of truth — Technical Spec §2), so a
/// session left mid-practice resumes exactly where it was left. The template
/// practice is never mutated by session state.
struct ExecutePracticeView: View {
    var session: PracticeSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var teamSetup: TeamSetupViewModel?
    @State private var showingFinishSummary = false
    @State private var showingDiscardConfirmation = false

    private var practice: Practice? {
        session.practice
    }

    private var participants: [PracticeSessionTeam] {
        session.sessionTeams
    }

    private var activities: [Activity] {
        practice?.orderedActivities ?? []
    }

    private var allDrills: [Drill] {
        activities.flatMap { $0.orderedDrills }
    }

    private var completeDrillCount: Int {
        allDrills.filter(isComplete).count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("\(completeDrillCount) of \(allDrills.count) drills", systemImage: "chart.bar")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(participants.count) participants")
                            .foregroundStyle(.secondary)
                    }
                }

                if participants.isEmpty {
                    Section {
                        Button {
                            teamSetup = TeamSetupViewModel(session: session, in: modelContext)
                        } label: {
                            Label("Add Participants", systemImage: "person.2")
                        }
                        Text("Add teams or players, then run the drills below.")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(activities) { activity in
                    Section(activity.title) {
                        ActivityTimer(allottedMinutes: activity.timeAllottedInMinutes)
                        ForEach(activity.orderedDrills) { drill in
                            drillCard(drill)
                        }
                    }
                }
            }
            .navigationTitle(practice?.title ?? "Execute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showingDiscardConfirmation = true
                    } label: {
                        Label("Discard", systemImage: "trash")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        teamSetup = TeamSetupViewModel(session: session, in: modelContext)
                    } label: {
                        Label("Participants", systemImage: "person.2")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        showingFinishSummary = true
                    }
                    .disabled(allDrills.isEmpty)
                }
            }
            .sheet(item: $teamSetup) { viewModel in
                TeamSetupSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingFinishSummary) {
                FinishSummarySheet(
                    session: session,
                    onKeep: {
                        try? modelContext.save()
                        dismiss()
                    },
                    onDiscard: {
                        discardSession()
                        dismiss()
                    }
                )
            }
            .confirmationDialog(
                "Discard this session?",
                isPresented: $showingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard Session", role: .destructive) {
                    discardSession()
                    dismiss()
                }
            } message: {
                Text("This deletes the recorded teams, check-offs, and scores. The practice itself is kept.")
            }
        }
    }

    // MARK: - Drills

    private func drillCard(_ drill: Drill) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: drill.isScored ? "star.fill" : "checkmark.circle")
                    .foregroundStyle(drill.isScored ? Color.yellow : (isAcknowledged(drill) ? Color.green : Color.secondary))
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
                if isComplete(drill) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            if let description = drill.drillDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if drill.isScored {
                if participants.isEmpty {
                    Text("Score each participant — add participants first.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else if drill.scoreOptions.isEmpty {
                    Text("Scored drill with no scoring config — edit the practice to set max points and step.")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else {
                    ForEach(participants) { participant in
                        scoreRow(drill, participant: participant)
                    }
                }
            } else {
                Button {
                    toggleAcknowledgement(drill)
                } label: {
                    Label(
                        isAcknowledged(drill) ? "Marked Done" : "Mark Done",
                        systemImage: isAcknowledged(drill) ? "checkmark" : "circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isAcknowledged(drill) ? .green : .accentColor)
            }
        }
        .padding(.vertical, 2)
    }

    private func scoreRow(_ drill: Drill, participant: PracticeSessionTeam) -> some View {
        let current = score(for: drill, participant: participant)
        return Menu {
            ForEach(drill.scoreOptions, id: \.self) { option in
                Button {
                    setScore(option, for: drill, participant: participant)
                } label: {
                    Label("\(option) pts", systemImage: current == option ? "checkmark" : "")
                }
            }
            if current != nil {
                Button("Clear Score", role: .destructive) {
                    setScore(nil, for: drill, participant: participant)
                }
            }
        } label: {
            HStack {
                Text(participant.team?.teamName ?? "—")
                Spacer()
                Text(current.map { "\($0) pts" } ?? "—")
                    .foregroundStyle(current == nil ? .secondary : .primary)
            }
        }
    }

    // MARK: - Session state

    private func isAcknowledged(_ drill: Drill) -> Bool {
        session.acknowledgements.contains { $0.drill?.id == drill.id && $0.isAcknowledged }
    }

    private func toggleAcknowledgement(_ drill: Drill) {
        if let existing = session.acknowledgements.first(where: { $0.drill?.id == drill.id }) {
            existing.isAcknowledged.toggle()
        } else {
            let acknowledgement = DrillAcknowledgement(drill: drill, isAcknowledged: true)
            modelContext.insert(acknowledgement)
            session.acknowledgements.append(acknowledgement)
        }
        try? modelContext.save()
    }

    private func score(for drill: Drill, participant: PracticeSessionTeam) -> Int? {
        participant.scores.first { $0.drill?.id == drill.id }?.score
    }

    private func setScore(_ value: Int?, for drill: Drill, participant: PracticeSessionTeam) {
        if let value {
            if let existing = participant.scores.first(where: { $0.drill?.id == drill.id }) {
                existing.score = value
            } else {
                let teamScore = TeamScore(drill: drill, score: value)
                modelContext.insert(teamScore)
                participant.scores.append(teamScore)
            }
        } else if let existing = participant.scores.first(where: { $0.drill?.id == drill.id }) {
            modelContext.delete(existing)
            participant.scores.removeAll { $0.id == existing.id }
        }
        try? modelContext.save()
    }

    /// A scored drill is complete once every participant has a score (a scored
    /// drill with no participants needs no scoring); an unscored drill is
    /// complete once checked off.
    private func isComplete(_ drill: Drill) -> Bool {
        if !drill.isScored {
            return isAcknowledged(drill)
        }
        return participants.allSatisfy { participant in
            score(for: drill, participant: participant) != nil
        }
    }

    /// Deletes the session record; scores, acknowledgements, and session teams
    /// cascade. Team templates (including provisioned "teams of 1") and the
    /// practice itself are kept for reuse.
    private func discardSession() {
        modelContext.delete(session)
        try? modelContext.save()
    }
}

// MARK: - Activity Timer

/// Countdown timer for one activity: start / pause / reset from the allotted
/// minutes. Kept deliberately simple — a coach running a practice needs one
/// glanceable clock, not a stopwatch suite.
private struct ActivityTimer: View {
    let allottedMinutes: Int

    @State private var remainingSeconds: Int?
    @State private var isRunning = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            Text("Time")
                .foregroundStyle(.secondary)
            Text(timeString)
                .font(.title3.monospacedDigit())
                .foregroundStyle(timeColor)
            Spacer()
            if isRunning {
                Button("Pause") {
                    isRunning = false
                }
                .buttonStyle(.bordered)
            } else {
                Button(remainingSeconds == nil ? "Start" : "Resume") {
                    if remainingSeconds == nil {
                        remainingSeconds = allottedMinutes * 60
                    }
                    isRunning = true
                }
                .buttonStyle(.borderedProminent)
            }
            if remainingSeconds != nil {
                Button("Reset") {
                    remainingSeconds = nil
                    isRunning = false
                }
                .buttonStyle(.bordered)
            }
        }
        .onReceive(ticker) { _ in
            guard isRunning, let remaining = remainingSeconds else { return }
            if remaining <= 1 {
                remainingSeconds = 0
                isRunning = false
            } else {
                remainingSeconds = remaining - 1
            }
        }
    }

    private var timeString: String {
        let remaining = remainingSeconds ?? allottedMinutes * 60
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private var timeColor: Color {
        if remainingSeconds == 0 { return .red }
        if remainingSeconds == nil { return .secondary }
        return .primary
    }
}

// MARK: - Finish Summary

/// Shown when the coach taps Finish: what was recorded, and whether to keep
/// the session record or discard it.
private struct FinishSummarySheet: View {
    var session: PracticeSession

    var onKeep: () -> Void
    var onDiscard: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var participants: [PracticeSessionTeam] {
        session.sessionTeams
    }

    private var allDrills: [Drill] {
        (session.practice?.orderedActivities ?? []).flatMap { $0.orderedDrills }
    }

    private var acknowledgementCount: Int {
        session.acknowledgements.filter(\.isAcknowledged).count
    }

    private var scoreCount: Int {
        session.sessionTeams.reduce(0) { $0 + $1.scores.count }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Session Summary") {
                    LabeledContent("Practice", value: session.practice?.title ?? "—")
                    LabeledContent("Date", value: session.createDate.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Participants", value: "\(participants.count)")
                    LabeledContent("Check-offs", value: "\(acknowledgementCount)")
                    LabeledContent("Scores recorded", value: "\(scoreCount)")
                }

                Section {
                    Text("The session is saved on this device. Cloud sync arrives in milestone M5.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Finish Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Discard") {
                        onDiscard()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Exit") {
                        onKeep()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

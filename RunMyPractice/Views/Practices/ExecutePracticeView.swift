import SwiftUI
import SwiftData

/// The practice execution screen (Functional Spec §6 "Execute Practice Flow", M4) —
/// the full view for running a practice session on the day.
///
/// The coach can:
/// - assign participants (TeamSetupSheet: named teams + solo players, the latter
///   as values-only "teams of 1" per Technical Spec §4),
/// - run an activity countdown timer,
/// - check off unscored drills (`DrillAcknowledgement`, session-scoped),
/// - score scored drills per participant (`TeamScore`) by sliding a stone to
///   the house (v0.9.0; the choices it snaps to are the drill's point step,
///   Technical Spec §5),
/// - finish (keeps the session record) or discard it.
///
/// All interactions write to the live `PracticeSession` and save immediately
/// (the local container is the source of truth — Technical Spec §2), so a
/// session left mid-practice resumes exactly where it was left. The template
/// practice is never mutated by session state, and the plan shown here comes
/// from the session's frozen snapshot (v0.5.0) — editing the template in
/// another window mid-run never rewrites an in-progress or recorded run.
/// Participants are displayed by their snapshotted `teamName`.
struct ExecutePracticeView: View {
    var session: PracticeSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var teamSetup: TeamSetupViewModel?
    @State private var showingFinishSummary = false
    @State private var showingDiscardConfirmation = false
    @State private var saveProblem: String?

    private var practice: Practice? {
        session.practice
    }

    private var participants: [PracticeSessionTeam] {
        session.sessionTeams
    }

    private var activities: [Activity] {
        session.orderedActivities
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
            .sheetSurface()
            .navigationTitle(session.practiceTitle ?? practice?.title ?? "Execute")
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
                        session.completedDate = Date()
                        do {
                            try modelContext.save()
                            dismiss()
                        } catch {
                            saveProblem = error.localizedDescription
                        }
                    },
                    onDiscard: {
                        discardSession()
                        dismiss()
                    }
                )
            }
            .alert("Couldn't Finish", isPresented: Binding(
                get: { saveProblem != nil },
                set: { if !$0 { saveProblem = nil } }
            )) {
                Button("OK") { }
            } message: {
                Text(saveProblem ?? "The run summary was not saved.")
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
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .sheetBackdrop()
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

            if let notes = drill.notes, !notes.isEmpty {
                Text(notes)
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
        HouseScoreControl(
            teamName: participant.teamName,
            maxPoints: drill.maxPoints ?? 0,
            step: drill.pointStep ?? 1,
            current: score(for: drill, participant: participant),
            handleColor: handleColor(for: participant),
            onScore: { setScore($0, for: drill, participant: participant) }
        )
    }

    /// The two classic handle colors, assigned per participant by a cheap name
    /// hash so each stone keeps the same handle between renders.
    private func handleColor(for participant: PracticeSessionTeam) -> Color {
        let sum = participant.teamName.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return sum.isMultiple(of: 2) ? Theme.stoneRed : Theme.stoneYellow
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

    /// Deletes the session record; scores, acknowledgements, session teams,
    /// and the frozen plan snapshot all cascade. The practice template and
    /// roster (teams/players) are kept for reuse.
    private func discardSession() {
        modelContext.delete(session)
        try? modelContext.save()
    }
}

// MARK: - House Scoring Control (v0.9.0)

/// Curling-flavored scoring control for a scored drill (v0.9.0): a granite
/// stone slides along the ice track, snapping to the drill's point step, with
/// the house rings at the max-points end — a perfect score parks the stone on
/// the button. Tap or drag anywhere on the track to set; an unscored
/// participant shows a hollow stone and "—", and the ✕ clears a recorded
/// score.
///
/// Replaces the segmented Picker / Menu of v0.4.1 with one visual metaphor
/// that works for any choice-matrix size. The score itself is a `TeamScore`
/// per participant (Technical Spec §5), written exactly as before — only the
/// way it is chosen changed.
private struct HouseScoreControl: View {
    let teamName: String
    let maxPoints: Int
    let step: Int
    let current: Int?
    var handleColor: Color
    let onScore: (Int?) -> Void

    /// The value being dragged before it is committed; nil when idle.
    @State private var draggedValue: Int?

    /// What the control shows right now (the in-progress drag wins).
    private var effectiveValue: Int? {
        draggedValue ?? current
    }

    /// The choice matrix this control snaps to (max 10, step 2 → 0,2,…,10).
    private var options: [Int] {
        generateScoreOptions(max: maxPoints, step: max(step, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(teamName)
                Spacer()
                Text(effectiveValue.map { "\($0) pts" } ?? "—")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(effectiveValue == nil ? .secondary : .primary)
                if current != nil {
                    Button {
                        onScore(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(teamName)'s score")
                }
            }

            track
                .frame(height: 48)
        }
    }

    // MARK: The sheet, the house, the stone

    private var track: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 0)
            let height = max(geo.size.height, 0)
            let midY = height / 2

            let houseSize: CGFloat = 40
            let stoneSize: CGFloat = 20
            let trackSize: CGFloat = 10

            // Stone-center travel: from the track's start to the button.
            let minX = stoneSize / 2
            let maxX = max(minX, width - houseSize / 2)

            let displayed = min(max(effectiveValue ?? 0, 0), max(maxPoints, 0))
            let fraction = maxPoints > 0 ? CGFloat(displayed) / CGFloat(maxPoints) : 0
            let stoneX = minX + (maxX - minX) * fraction

            ZStack {
                // The ice strip.
                Capsule()
                    .fill(Theme.iceDeep)
                    .frame(width: width, height: trackSize)
                    .position(x: width / 2, y: midY)

                // Progress fill up to the stone.
                if stoneX > minX {
                    Capsule()
                        .fill(Theme.button.opacity(0.35))
                        .frame(width: stoneX, height: trackSize)
                        .position(x: stoneX / 2, y: midY)
                }

                // The house at the max end.
                houseRings
                    .frame(width: houseSize, height: houseSize)
                    .position(x: width - houseSize / 2, y: midY)

                // The stone.
                stone
                    .frame(width: stoneSize, height: stoneSize)
                    .position(x: stoneX, y: midY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        draggedValue = steppedValue(at: gesture.location.x, minX: minX, maxX: maxX)
                    }
                    .onEnded { _ in
                        guard let value = draggedValue else { return }
                        draggedValue = nil
                        if value != current {
                            onScore(value)
                        }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(teamName) score")
            .accessibilityValue(effectiveValue.map { "\($0) points" } ?? "not scored")
            .accessibilityAdjustableAction { direction in
                guard !options.isEmpty else { return }
                let index = min(options.firstIndex(of: effectiveValue ?? 0) ?? 0, options.count - 1)
                switch direction {
                case .increment:
                    if index < options.count - 1 {
                        onScore(options[index + 1])
                    }
                case .decrement:
                    if index > 0 {
                        onScore(options[index - 1])
                    } else if effectiveValue != nil {
                        onScore(nil)
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    /// The choice-matrix value for a touch position: the nearest step
    /// increment, clamped to the track. Tapping the very start while
    /// unscored keeps the participant unscored — "0" and "—" are distinct
    /// choices (the ✕ or VoiceOver's down-arrow at zero is how to clear).
    private func steppedValue(at x: CGFloat, minX: CGFloat, maxX: CGFloat) -> Int? {
        guard maxPoints > 0, !options.isEmpty, maxX > minX else { return current }
        let fraction = min(1, max(0, (x - minX) / (maxX - minX)))
        let target = fraction * CGFloat(maxPoints)
        let value = options.min { abs(CGFloat($0) - target) < abs(CGFloat($1) - target) } ?? 0
        return (value == 0 && current == nil) ? nil : value
    }

    /// The house at the track's max end: the classic blue / white / red /
    /// white button. `Theme.ice` stands in for the white rings so the house
    /// blends into the sheet in both light and dark.
    private var houseRings: some View {
        ZStack {
            Circle().fill(Theme.button)                     // 12-ft ring
            Circle().fill(Theme.ice).scaleEffect(2.0 / 3.0) // 8-ft ring
            Circle().fill(Theme.stoneRed).scaleEffect(1.0 / 3.0) // 4-ft ring
            Circle().fill(Theme.ice).scaleEffect(0.28)      // the button
        }
        .overlay(
            Circle().strokeBorder(Theme.slate.opacity(0.35), lineWidth: 1)
        )
    }

    /// A granite stone seen from above, with its handle. Unscored
    /// participants get the hollow treatment: faded body, dashed outline.
    private var stone: some View {
        let scored = effectiveValue != nil
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.granite, Theme.granite.opacity(0.7)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: 18
                    )
                )
                .opacity(scored ? 1 : 0.4)
            if !scored {
                Circle()
                    .strokeBorder(Theme.slate, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            if scored {
                Capsule()
                    .fill(handleColor)
                    .frame(width: 10, height: 3.5)
            }
        }
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
        session.orderedActivities.flatMap { $0.orderedDrills }
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
                    LabeledContent("Practice", value: session.practiceTitle ?? session.practice?.title ?? "—")
                    LabeledContent("Date", value: session.createDate.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Participants", value: "\(participants.count)")
                    LabeledContent("Check-offs", value: "\(acknowledgementCount)")
                    LabeledContent("Scores recorded", value: "\(scoreCount)")
                }

                Section {
                    Text("The session is saved on this device. Cloud sync arrives in milestone M6.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .sheetSurface()
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
        .presentationDetents([.large])
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .sheetBackdrop()
    }
}

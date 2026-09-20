import SwiftUI
import SwiftData

/// Read-only view of a practice template (the "view" part of Functional Spec §5.4).
///
/// A practice is a reusable, freely editable/shareable plan. Each time it is
/// executed, a new `PracticeSession` is created that snapshots the plan at
/// run start (v0.5.0), so editing this template later — or sharing it with
/// another coach — never rewrites recorded runs.
///
/// The interactive parts:
/// - Editing/adding activities and drills: PracticeEditorView (M3)
/// - Live execution (teams, check-offs, scores): ExecutePracticeView (M4)
struct PracticeDetailView: View {
    var practice: Practice

    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false
    @State private var isEditing = false
    @State private var activeSession: PracticeSession?
    @State private var sessionStartProblem: String?

    var body: some View {
        List {
            Section {
                LabeledContent("Created", value: practice.createDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Activities", value: "\(practice.orderedActivities.count)")
                LabeledContent("Planned time", value: "\(practice.totalTimeInMinutes) min")
            }

            if practice.orderedActivities.isEmpty {
                Section {
                    Text("No activities yet — edit this practice to add some.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Activities") {
                    ForEach(practice.orderedActivities) { activity in
                        activitySection(activity)
                    }
                }
            }
        }
        .navigationTitle(practice.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                startSession()
            } label: {
                Label("Execute Practice", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(practice.orderedActivities.isEmpty)
            .padding()
            .background(.bar)
        }
        .fullScreenCover(isPresented: $isEditing) {
            PracticeEditorView(practice: practice)
        }
        .fullScreenCover(item: $activeSession) { session in
            ExecutePracticeView(session: session)
        }
        .alert("Couldn't Start Practice", isPresented: Binding(
            get: { sessionStartProblem != nil },
            set: { if !$0 { sessionStartProblem = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(sessionStartProblem ?? "The session could not be saved.")
        }
        .confirmationDialog(
            "Delete this practice?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deletePractice()
            }
        } message: {
            Text("This removes the practice template. Recorded runs are kept — each keeps a frozen copy of the plan as it was run.")
        }
    }

    private func activitySection(_ activity: Activity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(activity.title)
                    .font(.headline)
                Spacer()
                Text("\(activity.timeAllottedInMinutes) min")
                    .foregroundStyle(.secondary)
            }
            if let description = activity.activityDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(activity.orderedDrills) { drill in
                drillRow(drill)
            }
        }
        .padding(.vertical, 2)
    }

    private func drillRow(_ drill: Drill) -> some View {
        HStack(spacing: 6) {
            Image(systemName: drill.isScored ? "star.fill" : "checkmark.circle")
                .font(.caption)
                .foregroundStyle(drill.isScored ? Color.yellow : Color.secondary)
            Text(drill.title)
                .font(.subheadline)
            Spacer()
            if drill.isScored, let maxPoints = drill.maxPoints {
                Text("0–\(maxPoints) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("check-off")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Resumes the in-progress (unsynced) session for this practice, or starts
    /// a new one. Leaving the execute screen keeps the session, so an
    /// interrupted practice resumes where it was left (offline-first, §2).
    ///
    /// New sessions snapshot the plan at run start (`PracticeSession.start`) —
    /// resume never re-snapshots, so a half-finished run keeps the plan it
    /// was started with.
    private func startSession() {
        if let current = practice.currentSession(in: modelContext) {
            activeSession = current
            return
        }
        do {
            activeSession = try PracticeSession.start(for: practice, in: modelContext)
        } catch {
            // Don't open the execute screen for a session that couldn't be
            // persisted — surface the failure instead.
            sessionStartProblem = error.localizedDescription
        }
    }

    private func deletePractice() {
        // Delete activities explicitly (drills cascade with their activity).
        // Recorded runs are safe (v0.5.0): sessions keep their own frozen plan
        // snapshot, and their `practice` reference (provenance only) is
        // nullified by the template deletion. NOTE (M5): when sync lands,
        // template deletion must be handled explicitly server-side.
        for activity in practice.activities {
            modelContext.delete(activity)
        }
        modelContext.delete(practice)
        try? modelContext.save()
    }
}

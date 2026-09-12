import SwiftUI
import SwiftData

/// Read-only view of a practice template (the "view" part of Functional Spec §5.4).
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
        .confirmationDialog(
            "Delete this practice?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deletePractice()
            }
        } message: {
            Text("This removes the practice and its activities and drills.")
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
    private func startSession() {
        if let current = practice.currentSession(in: modelContext) {
            activeSession = current
            return
        }
        let session = PracticeSession(practice: practice)
        modelContext.insert(session)
        try? modelContext.save()
        activeSession = session
    }

    private func deletePractice() {
        // Delete activities explicitly (drills cascade with their activity).
        // NOTE (M5): sessions reference the practice template (tech spec §7) —
        // when sync lands, template deletion must be handled explicitly.
        for activity in practice.activities {
            modelContext.delete(activity)
        }
        modelContext.delete(practice)
        try? modelContext.save()
    }
}

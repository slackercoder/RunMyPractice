import SwiftUI
import SwiftData

/// The practice editor (Functional Spec §6 "Edit Practice Flow") — a full
/// view for editing a practice, whether an existing one or a blank "new" one.
///
/// Edits apply to the SwiftData models in place (the local container is the
/// single source of truth — Technical Spec §2):
/// - Structural changes (add / remove / reorder) apply immediately.
/// - Field edits go through form sheets (ActivityFormView / DrillFormView).
/// - Done persists; Cancel rolls back the whole visit, which also removes a
///   blank practice created for the new-practice flow.
struct PracticeEditorView: View {
    var practice: Practice

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var activityForm: ActivityFormViewModel?
    @State private var drillForm: DrillFormViewModel?
    @State private var expandedActivities: Set<UUID> = []

    private var orderedActivities: [Activity] {
        practice.orderedActivities
    }

    private var trimmedTitle: String {
        practice.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var titleIsInvalid: Bool {
        trimmedTitle.isEmpty || trimmedTitle.count > 150
    }

    var body: some View {
        @Bindable var practice = practice

        NavigationStack {
            List {
                Section {
                    TextField("Practice title", text: $practice.title)
                } footer: {
                    if titleIsInvalid {
                        Text("The title must be 1–150 characters.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Activities") {
                    ForEach(orderedActivities) { activity in
                        activityDisclosure(activity)
                    }
                    .onMove(perform: moveActivities)

                    Button {
                        addActivity()
                    } label: {
                        Label("Add Activity", systemImage: "plus.circle")
                    }
                }

                if orderedActivities.isEmpty {
                    Section {
                        Text("Add your first activity — a warm-up, game scenarios, or anything that goes into a practice.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(trimmedTitle.isEmpty ? "Practice" : trimmedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        done()
                    }
                    .disabled(titleIsInvalid)
                }
            }
            .sheet(item: $activityForm) { viewModel in
                ActivityFormView(viewModel: viewModel)
            }
            .sheet(item: $drillForm) { viewModel in
                DrillFormView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Activities

    private func activityDisclosure(_ activity: Activity) -> some View {
        DisclosureGroup(isExpanded: isExpanded(activity)) {
            ForEach(activity.orderedDrills) { drill in
                drillRow(drill, in: activity)
            }
            .onMove { moveDrills(in: activity, from: $0, to: $1) }

            Button {
                addDrill(to: activity)
            } label: {
                Label("Add Drill", systemImage: "plus.circle")
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.headline)
                Text("\(activity.timeAllottedInMinutes) min · \(activity.orderedDrills.count) drills")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                activityForm = ActivityFormViewModel(activity: activity, parentPractice: practice, isCreating: false)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(activity) // drills cascade with their activity
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Drills

    private func drillRow(_ drill: Drill, in activity: Activity) -> some View {
        HStack(spacing: 6) {
            Image(systemName: drill.isScored ? "star.fill" : "checkmark.circle")
                .font(.caption)
                .foregroundStyle(drill.isScored ? Color.yellow : Color.secondary)
            Text(drill.title)
            Spacer()
            if drill.isCoachDrill {
                Text("coach")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            if drill.isScored, let maxPoints = drill.maxPoints {
                Text("0–\(maxPoints) pts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !drill.isScored {
                Text("check-off")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                drillForm = DrillFormViewModel(drill: drill, parentActivity: activity, isCreating: false)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(drill)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Actions

    private func addActivity() {
        let activity = Activity(title: "New Activity", timeAllottedInMinutes: 10, order: orderedActivities.count)
        modelContext.insert(activity)
        practice.activities.append(activity)
        expandedActivities.insert(activity.id)
        activityForm = ActivityFormViewModel(activity: activity, parentPractice: practice, isCreating: true)
    }

    private func addDrill(to activity: Activity) {
        let drill = Drill(title: "New Drill", isScored: false, order: activity.orderedDrills.count)
        modelContext.insert(drill)
        activity.drills.append(drill)
        drillForm = DrillFormViewModel(drill: drill, parentActivity: activity, isCreating: true)
    }

    private func moveActivities(from source: IndexSet, to destination: Int) {
        var items = orderedActivities
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.order = index
        }
    }

    private func moveDrills(in activity: Activity, from source: IndexSet, to destination: Int) {
        var items = activity.orderedDrills
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.order = index
        }
    }

    private func isExpanded(_ activity: Activity) -> Binding<Bool> {
        Binding(
            get: { expandedActivities.contains(activity.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedActivities.insert(activity.id)
                } else {
                    expandedActivities.remove(activity.id)
                }
            }
        )
    }

    private func done() {
        guard !titleIsInvalid else { return }
        practice.title = trimmedTitle
        try? modelContext.save()
        dismiss()
    }

    private func cancel() {
        // Rolls back everything made during this editor visit, including a
        // blank practice created for the new-practice flow.
        modelContext.rollback()
        dismiss()
    }
}

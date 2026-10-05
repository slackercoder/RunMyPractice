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
    @State private var showingActivityPicker = false
    @State private var drillPickerActivity: Activity?
    @State private var expandedActivities: Set<UUID> = []
    @State private var activityToDelete: Activity?
    @State private var drillToDelete: Drill?
    @State private var saveProblem: String?

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
                        showingActivityPicker = true
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
            .sheetSurface()
            .navigationTitle(trimmedTitle.isEmpty ? "Practice" : trimmedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    // v0.11.0: enables drag-reordering of the activity rows
                    // (their .onMove handlers were otherwise unreachable).
                    EditButton()
                }
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
            .sheet(item: $drillPickerActivity) { target in
                DrillPickerSheet(activity: target) { selected in
                    // The picker performs the model work (a new placeholder
                    // or a copy of a library drill); the editor then opens
                    // the form so the user can rename the row on the spot.
                    //
                    // v0.13.0: nil the picker first, then present the form on
                    // the next runloop turn. Presenting a sheet in the *same
                    // transaction* that dismisses a sibling sheet on this same
                    // container makes SwiftUI present the new sheet blank — the
                    // reported empty drill form.
                    expandedActivities.insert(target.id)
                    drillPickerActivity = nil
                    Task { @MainActor in
                        drillForm = DrillFormViewModel(drill: selected, parentActivity: target, isCreating: true)
                    }
                }
            }
            .sheet(isPresented: $showingActivityPicker) {
                ActivityPickerSheet(practice: practice) { selected in
                    // The picker performs the model work (new placeholder or a
                    // copy of an existing activity); the editor then opens the
                    // form so the user can rename the row on the spot.
                    //
                    // v0.13.0: same one-tick deferral as the drill path — the
                    // form must present after the picker's dismissal, not in
                    // the same transaction, or the new sheet can come up blank.
                    expandedActivities.insert(selected.id)
                    showingActivityPicker = false
                    Task { @MainActor in
                        activityForm = ActivityFormViewModel(activity: selected, parentPractice: practice, isCreating: true)
                    }
                }
            }
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .sheetBackdrop()
        .alert("Couldn't Save", isPresented: Binding(
            get: { saveProblem != nil },
            set: { if !$0 { saveProblem = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveProblem ?? "Your changes were not saved.")
        }
        // v0.13.0: confirm before destroying — and reassure about copies.
        .confirmationDialog(
            "Delete this activity?",
            isPresented: Binding(
                get: { activityToDelete != nil },
                set: { if !$0 { activityToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let activity = activityToDelete {
                    modelContext.delete(activity) // drills cascade with their activity
                }
            }
        } message: {
            if let activity = activityToDelete {
                Text("This removes \"\(activity.title)\" and its \(activity.orderedDrills.count) drill\(activity.orderedDrills.count == 1 ? "" : "s") from this practice only — other practices and the drill library keep their own copies.")
            }
        }
        .confirmationDialog(
            "Delete this drill?",
            isPresented: Binding(
                get: { drillToDelete != nil },
                set: { if !$0 { drillToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let drill = drillToDelete else { return }
                // Copy-never-reference: remove this practice's copy only; a
                // library drill of the same name and other practices' copies
                // are untouched.
                if let activity = practice.orderedActivities.first(where: {
                    $0.drills.contains(where: { $0.id == drill.id })
                }) {
                    activity.drills.removeAll { $0.id == drill.id }
                }
                modelContext.delete(drill)
            }
        } message: {
            if let drill = drillToDelete {
                Text("This removes \"\(drill.title)\" from this practice only — the drill library and other practices keep their own copies.")
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
                // v0.12.0: pick — a fresh drill or a copy from the library.
                // v0.13.0: item-based presentation (see the sheet below) — one
                // source of truth instead of a boolean plus an optional.
                drillPickerActivity = activity
            } label: {
                Label("Add Drill", systemImage: "plus.circle")
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.title)
                        .font(.headline)
                    Text("\(activity.timeAllottedInMinutes) min · \(activity.orderedDrills.count) drills")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // v0.13.0: explicit delete with confirmation — a swipe is not
                // a fat-finger-friendly affordance (drills cascade).
                Button {
                    activityToDelete = activity
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Delete \(activity.title)")
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
    }

    // MARK: - Drills

    private func drillRow(_ drill: Drill, in activity: Activity) -> some View {
        HStack(spacing: 8) {
            Image(systemName: drill.isScored ? "star.fill" : "checkmark.circle")
                .font(.body)
                .foregroundStyle(drill.isScored ? Color.yellow : Color.secondary)
            Text(drill.title)
            Spacer()
            // v0.11.0: drills live inside a DisclosureGroup, where SwiftUI's
            // drag-reordering doesn't reach — explicit up/down instead.
            moveButtons(drill: drill, in: activity)
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
            // v0.13.0: explicit delete with confirmation — a swipe is not a
            // fat-finger-friendly affordance.
            Button {
                drillToDelete = drill
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Delete \(drill.title)")
        }
        .swipeActions(edge: .leading) {
            Button {
                drillForm = DrillFormViewModel(drill: drill, parentActivity: activity, isCreating: false)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .padding(.vertical, 4)
    }

    /// Up/down controls for a drill within its activity (v0.11.0). A move
    /// rewrites the sibling order values; Done persists, Cancel rolls back.
    /// Each button carries a generous 44pt hit area (v0.13.0; was 36pt in v0.11.1).
    private func moveButtons(drill: Drill, in activity: Activity) -> some View {
        HStack(spacing: 6) {
            Button {
                drill.move(up: true, in: activity)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!drill.canMoveUp(in: activity))
            Button {
                drill.move(up: false, in: activity)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!drill.canMoveDown(in: activity))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Move \(drill.title)")
    }

    // MARK: - Actions

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
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Stay in the editor: the changes are still in the model context,
            // so the user can retry or Cancel rather than losing them silently.
            saveProblem = error.localizedDescription
        }
    }

    private func cancel() {
        // Rolls back everything made during this editor visit, including a
        // blank practice created for the new-practice flow.
        modelContext.rollback()
        dismiss()
    }
}

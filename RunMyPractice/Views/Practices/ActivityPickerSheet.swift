import SwiftUI
import SwiftData

/// The "Add Activity" choice (v0.10.0): start a brand-new activity, or
/// choose an existing one from the coach's other practices.
///
/// Choosing an existing activity makes a **copy** (the activity and all its
/// drills, with fresh client UUIDs) rather than a reference: every practice
/// stays a self-contained template (Technical Spec §2), so editing the copy
/// can never touch the original — the same rule sharing will follow.
///
/// The sheet only makes the choice and performs the model work; it reports
/// the result back through `onSelect`, and the presenting editor dismisses
/// it and opens the form so the user can rename the new row on the spot.
struct ActivityPickerSheet: View {
    let practice: Practice
    var onSelect: (Activity) -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Practice.title) private var allPractices: [Practice]

    /// Every activity the picker offers: everything except the practice being
    /// edited (choosing one of its own activities would just duplicate it in
    /// place), alphabetized with the source practice for context.
    private var existingActivities: [(activity: Activity, sourceTitle: String)] {
        allPractices
            .filter { $0.id != practice.id }
            .flatMap { source in
                source.orderedActivities.map { ($0, source.title) }
            }
            .sorted {
                $0.activity.title.localizedCaseInsensitiveCompare($1.activity.title) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        chooseNewActivity()
                    } label: {
                        Label("Start a New Activity", systemImage: "plus.circle")
                    }
                }

                Section("Choose an Existing Activity") {
                    if existingActivities.isEmpty {
                        Text("No activities in your other practices yet — start a new one instead.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(existingActivities, id: \.activity.id) { entry in
                            Button {
                                chooseCopy(of: entry.activity)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.activity.title)
                                    Text("\(entry.sourceTitle) · \(entry.activity.timeAllottedInMinutes) min · \(entry.activity.orderedDrills.count) drills")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .sheetSurface()
            .navigationTitle("Add Activity")
            .navigationBarTitleDisplayMode(.inline)
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .sheetBackdrop()
        .presentationDetents([.large])
    }

    private func chooseNewActivity() {
        let activity = Activity(title: "New Activity", timeAllottedInMinutes: 10, order: practice.orderedActivities.count)
        modelContext.insert(activity)
        practice.activities.append(activity)
        onSelect(activity)
    }

    private func chooseCopy(of source: Activity) {
        onSelect(source.copy(into: practice, in: modelContext))
    }
}

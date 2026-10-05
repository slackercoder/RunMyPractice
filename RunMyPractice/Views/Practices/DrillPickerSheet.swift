import SwiftUI
import SwiftData

/// The "Add Drill" choice (v0.12.0): start a brand-new drill, or choose one
/// from the coach's drill library (the Drills tab).
///
/// Choosing a library drill makes a **copy** — a `Drill` with a fresh client
/// UUID, appended to the activity — rather than a reference (the same
/// copy-never-reference rule activities follow, v0.10.0). The library entry
/// is a *starting point*: practices stay self-contained templates, and
/// editing the copy can never touch the library drill.
///
/// The sheet only makes the choice and performs the model work; it reports
/// the result back through `onSelect`, and the presenting editor dismisses
/// it and opens the drill form so the user can rename the new row on the spot.
struct DrillPickerSheet: View {
    let activity: Activity
    var onSelect: (Drill) -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DrillLibrary.title) private var library: [DrillLibrary]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        chooseNewDrill()
                    } label: {
                        Label("Start a New Drill", systemImage: "plus.circle")
                    }
                }

                Section("From the Drill Library") {
                    if library.isEmpty {
                        Text("No library drills yet — start a new one instead, or build up your library from the Drills tab.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(library) { entry in
                            Button {
                                chooseCopy(of: entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                    Text(subtitle(for: entry))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .sheetSurface()
            .navigationTitle("Add Drill")
            .navigationBarTitleDisplayMode(.inline)
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .sheetBackdrop()
        .presentationDetents([.large])
    }

    private func subtitle(for entry: DrillLibrary) -> String {
        var parts = [entry.isScored ? "\(entry.maxPoints ?? 0) pts" : "check-off"]
        if entry.isCoachDrill {
            parts.append("coach-only")
        }
        return parts.joined(separator: " · ")
    }

    private func chooseNewDrill() {
        let drill = Drill(title: "New Drill", isScored: false, order: activity.orderedDrills.count)
        modelContext.insert(drill)
        activity.drills.append(drill)
        onSelect(drill)
    }

    private func chooseCopy(of source: DrillLibrary) {
        onSelect(source.copy(into: activity, in: modelContext))
    }
}

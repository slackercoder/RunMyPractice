import SwiftUI
import SwiftData

/// The Drills tab (v0.12.0): the coach's standalone drill library — a pool of
/// drills built once and dropped into any activity when assembling a practice.
///
/// List / search / create / edit / delete, all in place (Functional Spec
/// §5.6). Row tap opens the form sheet directly — there is no detail view: a
/// drill is fully described by its form fields, so a separate screen would
/// just add a hop. This follows the Players tab's page pattern
/// (ContentUnavailableView + add + confirmationDialog delete) with the
/// Practices tab's `.searchable` added on top.
struct DrillsHomeView: View {
    @Query(sort: \DrillLibrary.title)
    private var drills: [DrillLibrary]

    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var form: DrillLibraryFormViewModel?
    @State private var pendingDelete: DrillLibrary?

    private var filteredDrills: [DrillLibrary] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return drills }
        return drills.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || ($0.drillDescription ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if drills.isEmpty {
                    ContentUnavailableView {
                        Label("No Library Drills Yet", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("Build a drill once, then drop it into any activity when assembling a practice.")
                    } actions: {
                        Button("Add Drill") {
                            startNewDrill()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if filteredDrills.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredDrills) { drill in
                        row(drill)
                    }
                    .sheetSurface()
                }
            }
            .navigationTitle("Drills")
            .searchable(text: $searchText, prompt: "Search drills")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startNewDrill()
                    } label: {
                        Label("Add Drill", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $form) { viewModel in
                DrillLibraryFormView(viewModel: viewModel)
            }
            .confirmationDialog(
                "Delete this drill?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete \(pendingDelete?.title ?? "")", role: .destructive) {
                    if let drill = pendingDelete {
                        modelContext.delete(drill)
                        try? modelContext.save()
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            }
        }
    }

    private func row(_ drill: DrillLibrary) -> some View {
        Button {
            form = DrillLibraryFormViewModel(drill: drill, isCreating: false)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(drill.title)
                        .font(.headline)
                    Text(subtitle(for: drill))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .swipeActions {
            Button(role: .destructive) {
                pendingDelete = drill
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func subtitle(for drill: DrillLibrary) -> String {
        var parts = [drill.isScored ? "\(drill.maxPoints ?? 0) pts" : "check-off"]
        if drill.isCoachDrill {
            parts.append("coach-only")
        }
        return parts.joined(separator: " · ")
    }

    /// Creates a blank library drill (inserted but unsaved) and opens the
    /// form with it. Cancel in the form deletes the draft; Save persists it.
    private func startNewDrill() {
        let drill = DrillLibrary(title: "New Drill", isScored: false)
        modelContext.insert(drill)
        form = DrillLibraryFormViewModel(drill: drill, isCreating: true)
    }
}

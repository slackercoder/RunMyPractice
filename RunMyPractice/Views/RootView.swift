import SwiftUI

/// Root navigation shell for the RunMy Practice app.
///
/// MVP flow (Functional Spec §2, §6) with no authentication:
/// - **Practices** — list / search / create (M2), editor (M3), execute (M4)
/// - **Drills**    — the reusable drill library (v0.12.0): build drills once,
///                   then drop them into any activity when assembling a practice
/// - **Runs**      — run history & read-only review (v0.6.0)
/// - **Players**   — roster management (M2)
///
/// Also the sync worker's (M6b) trigger point: when the app becomes active
/// with unsynced data, `SyncService.syncNow()` pushes it to the Practice
/// sync API. Sync state is displayed on the Practices tab.
struct RootView: View {
    @Environment(SyncService.self) private var syncService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            PracticesHomeView()
                .tabItem {
                    Label("Practices", systemImage: "target")
                }

            DrillsHomeView()
                .tabItem {
                    Label("Drills", systemImage: "square.stack.3d.up")
                }

            RunsListView()
                .tabItem {
                    Label("Runs", systemImage: "clock.arrow.circlepath")
                }

            PlayersListView()
                .tabItem {
                    Label("Players", systemImage: "person.2")
                }
        }
        .tint(Theme.tint)
        .fontDesign(.rounded)
        .tabBarIce()
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, syncService.needsSync {
                syncService.syncNow()
            }
        }
        .onAppear {
            if syncService.needsSync {
                syncService.syncNow()
            }
        }
    }
}

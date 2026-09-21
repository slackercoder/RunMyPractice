import SwiftUI

/// Root navigation shell for the RunMy Practice app.
///
/// MVP flow (Functional Spec §2, §6) with no authentication:
/// - **Practices** — list / search / create (M2), editor (M3), execute (M4)
/// - **Runs**      — run history & read-only review (v0.6.0)
/// - **Players**   — roster management (M2)
struct RootView: View {
    var body: some View {
        TabView {
            PracticesHomeView()
                .tabItem {
                    Label("Practices", systemImage: "target")
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
    }
}

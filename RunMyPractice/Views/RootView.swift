import SwiftUI

/// Root navigation shell for the RunMy Practice app.
///
/// MVP flow (Functional Spec §2, §6) with no authentication:
/// - **Practices** — list / search / create (M2), editor (M3), execute (M4)
/// - **Players**   — roster management (M2)
struct RootView: View {
    var body: some View {
        TabView {
            PracticesHomeView()
                .tabItem {
                    Label("Practices", systemImage: "list.bullet.rectangle")
                }

            PlayersListView()
                .tabItem {
                    Label("Players", systemImage: "person.2")
                }
        }
    }
}

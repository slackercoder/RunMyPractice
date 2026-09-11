import SwiftUI

/// Root navigation shell for the RunMy Practice app.
///
/// MVP flow (Functional Spec §2, §6) with no authentication:
/// - **Practices** — list / search / create (M2) and execute (M4)
/// - **Players**   — roster management (M2)
struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                PracticesPlaceholderView()
            }
            .tabItem {
                Label("Practices", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                PlayersPlaceholderView()
            }
            .tabItem {
                Label("Players", systemImage: "person.2")
            }
        }
    }
}

/// M1 placeholder — the home screen (list, search, create, execute) lands in M2/M4.
private struct PracticesPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Practices", systemImage: "list.bullet.rectangle")
        } description: {
            Text("Milestone M2 adds your practice list, search, and create.")
        }
    }
}

/// M1 placeholder — the roster screen (list, add, remove players) lands in M2.
private struct PlayersPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Players", systemImage: "person.2")
        } description: {
            Text("Milestone M2 adds roster management.")
        }
    }
}

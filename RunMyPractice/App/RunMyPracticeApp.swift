import SwiftUI
import SwiftData

/// Entry point for the RunMy Practice app.
///
/// Offline-first (Technical Spec §2): the local SwiftData container is the
/// single source of truth for the UI. There is no authentication in the MVP;
/// all data lives on-device until the sync layer (M5) is added.
@main
struct RunMyPracticeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Practice.self,
            Activity.self,
            Drill.self,
            Team.self,
            Player.self,
            PracticeSession.self,
            PracticeSessionTeam.self,
            TeamScore.self,
            DrillAcknowledgement.self,
        ])
    }
}

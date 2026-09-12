import Foundation
import SwiftData

/// Convenience accessors for ordered relationships. SwiftData does not
/// guarantee relationship array order, so views always sort explicitly.
extension Practice {
    /// Activities in intended run order.
    var orderedActivities: [Activity] {
        activities.sorted { $0.order < $1.order }
    }

    /// Sum of allotted time across all activities.
    var totalTimeInMinutes: Int {
        activities.reduce(0) { $0 + $1.timeAllottedInMinutes }
    }

    /// The in-progress execution of this practice, if one exists: the most
    /// recent session that has not been synced yet (synced sessions are
    /// finished runs). Session counts are small on-device, so fetch and filter
    /// rather than predicate on the optional practice relationship.
    func currentSession(in context: ModelContext) -> PracticeSession? {
        let sessions = (try? context.fetch(FetchDescriptor<PracticeSession>())) ?? []
        return sessions
            .filter { !$0.isSynced && $0.practice?.id == id }
            .max { $0.createDate < $1.createDate }
    }
}

extension Activity {
    /// Drills in intended run order.
    var orderedDrills: [Drill] {
        drills.sorted { $0.order < $1.order }
    }
}

extension Player {
    /// Deletes the player, plus any provisioned solo "team of 1" records it
    /// owns (otherwise empty team records would linger), and unlinks the
    /// player's session participant entries from any sessions (so the roster
    /// never shows a ghost "—" participant). Deleting the session team rows
    /// cascades their recorded scores.
    func delete(in context: ModelContext) {
        let teams = (try? context.fetch(FetchDescriptor<Team>())) ?? []
        let soloTeams = teams.filter { $0.players.count == 1 && $0.players.first?.id == id }
        for team in soloTeams {
            let sessions = (try? context.fetch(FetchDescriptor<PracticeSession>())) ?? []
            for session in sessions {
                for sessionTeam in session.sessionTeams where sessionTeam.team?.id == team.id {
                    context.delete(sessionTeam)
                    session.sessionTeams.removeAll { $0.id == sessionTeam.id }
                }
            }
            context.delete(team)
        }
        context.delete(self)
    }
}

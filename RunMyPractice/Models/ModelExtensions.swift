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
    /// recent session that is neither completed (v0.6.0: `completedDate` set
    /// on Finish) nor synced yet. Finished runs never resurface on resume —
    /// they live in the Runs list for review, and the next "Execute Practice"
    /// starts a fresh run of the (possibly edited) template.
    ///
    /// Session counts are small on-device, so fetch and filter rather than
    /// predicate on the optional practice relationship.
    func currentSession(in context: ModelContext) -> PracticeSession? {
        let sessions = (try? context.fetch(FetchDescriptor<PracticeSession>())) ?? []
        return sessions
            .filter { !$0.isSynced && $0.completedDate == nil && $0.practice?.id == id }
            .max { $0.createDate < $1.createDate }
    }
}

extension Activity {
    /// Drills in intended run order.
    var orderedDrills: [Drill] {
        drills.sorted { $0.order < $1.order }
    }
}

extension PracticeSession {
    /// When this run counts toward player standings (v0.7.0): the completion
    /// time, or the start time for in-progress runs (and for legacy runs
    /// recorded before v0.6.0 introduced the completion date).
    var standingsDate: Date {
        completedDate ?? createDate
    }
}

extension Player {
    /// The player's current standings total (v0.7.0): every point earned in
    /// runs whose `standingsDate` is after `resetDate` where the player's
    /// label was on the team that scored. One rule covers both cases a coach
    /// cares about — points earned as part of a team (each member earns the
    /// team's score) and points earned solo (a team of one) — because both
    /// live on the same per-team score records.
    ///
    /// Attribution follows the player's **current label**: runs snapshot
    /// labels, not identity (v0.5.0), so treat labels as permanent once
    /// assigned. Renaming a player re-attributes runs recorded under the new
    /// label; past runs recorded under the old label no longer count.
    ///
    /// Computed rather than stored, so run deletion/editing can never leave
    /// a stale tally behind. Run counts are small on-device, so the
    /// in-memory sweep is fine. NOTE (M6): when sync lands, materialize this
    /// per-user server-side for cross-device standings.
    func totalPoints(in sessions: [PracticeSession], since resetDate: Date?) -> Int {
        sessions
            .filter { session in
                guard let resetDate else { return true }
                return session.standingsDate > resetDate
            }
            .flatMap(\.sessionTeams)
            .filter { $0.playerLabels.contains(playerName) }
            .flatMap(\.scores)
            .reduce(0) { $0 + $1.score }
    }

    /// Deletes the roster player plus any solo "team of 1" records it owns
    /// (otherwise empty team records would linger). Membership in named
    /// teams nullifies automatically. Recorded runs are untouched (v0.5.0):
    /// sessions snapshot their groups as values, so a player deleted from the
    /// roster still exists as a frozen label in every run that recorded them.
    func delete(in context: ModelContext) {
        let teams = (try? context.fetch(FetchDescriptor<Team>())) ?? []
        let soloTeams = teams.filter { $0.players.count == 1 && $0.players.first?.id == id }
        for team in soloTeams {
            context.delete(team)
        }
        context.delete(self)
    }
}

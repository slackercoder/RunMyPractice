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

    /// Copies this activity — and every drill it contains — into `practice`
    /// as fresh records (v0.10.0), and returns the inserted copy.
    ///
    /// **Copy, never reference.** Activities are *reusable* by copying: each
    /// practice stays a self-contained template (Technical Spec §2), so the
    /// copy gets fresh client UUIDs and `remoteId == nil` and syncs as its
    /// own records. Editing the copy can therefore never affect the original —
    /// which is also the rule activity sharing will follow when it lands.
    /// Template `runNotes` stay nil: runs journal their own observations (v0.9.1).
    @discardableResult
    func copy(into practice: Practice, in context: ModelContext) -> Activity {
        let creator = practice.createdBy ?? createdBy
        let copy = Activity(
            title: title,
            activityDescription: activityDescription,
            timeAllottedInMinutes: timeAllottedInMinutes,
            order: practice.orderedActivities.count,
            createdBy: creator
        )
        context.insert(copy)

        for (index, drill) in orderedDrills.enumerated() {
            let drillCopy = Drill(
                title: drill.title,
                drillDescription: drill.drillDescription,
                notes: drill.notes,
                runNotes: nil,
                isScored: drill.isScored,
                maxPoints: drill.maxPoints,
                pointStep: drill.pointStep,
                isCoachDrill: drill.isCoachDrill,
                order: index,
                createdBy: creator
            )
            context.insert(drillCopy)
            copy.drills.append(drillCopy)
        }

        practice.activities.append(copy)
        return copy
    }

    // MARK: - Reordering (v0.11.0)

    /// The activity's position within its parent practice, or nil if it
    /// doesn't belong to it.
    private func position(in practice: Practice) -> (index: Int, count: Int)? {
        let items = practice.orderedActivities
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return (index, items.count)
    }

    /// Whether `move(up:)` / `move(down:)` would swap with a neighbor.
    func canMoveUp(in practice: Practice) -> Bool {
        position(in: practice).map { $0.index > 0 } ?? false
    }

    func canMoveDown(in practice: Practice) -> Bool {
        position(in: practice).map { $0.index < $0.count - 1 } ?? false
    }

    /// Swaps the order with the neighboring activity and reindexes the
    /// siblings to a sequential 0...n-1.
    ///
    /// Runs execute in this order: a session snapshots the order values at
    /// run start (v0.5.0), so a reorder takes effect from the next execution.
    /// The `order` column is synced as part of the full template upsert, so
    /// no schema change is involved.
    @discardableResult
    func move(up: Bool, in practice: Practice) -> Bool {
        guard let (index, count) = position(in: practice) else { return false }
        let target = up ? index - 1 : index + 1
        guard (0..<count).contains(target) else { return false }
        var items = practice.orderedActivities
        items.move(fromOffsets: IndexSet(integer: index), toOffset: up ? target : target + 1)
        for (i, item) in items.enumerated() {
            item.order = i
        }
        return true
    }
}

extension Drill {
    // MARK: - Reordering (v0.11.0)

    /// The drill's position within its parent activity, or nil if it doesn't
    /// belong to it.
    private func position(in activity: Activity) -> (index: Int, count: Int)? {
        let items = activity.orderedDrills
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return (index, items.count)
    }

    func canMoveUp(in activity: Activity) -> Bool {
        position(in: activity).map { $0.index > 0 } ?? false
    }

    func canMoveDown(in activity: Activity) -> Bool {
        position(in: activity).map { $0.index < $0.count - 1 } ?? false
    }

    /// Swaps the order with the neighboring drill within its activity and
    /// reindexes the siblings to a sequential 0...n-1 (same semantics as
    /// `Activity.move(up:in:)`).
    @discardableResult
    func move(up: Bool, in activity: Activity) -> Bool {
        guard let (index, count) = position(in: activity) else { return false }
        let target = up ? index - 1 : index + 1
        guard (0..<count).contains(target) else { return false }
        var items = activity.orderedDrills
        items.move(fromOffsets: IndexSet(integer: index), toOffset: up ? target : target + 1)
        for (i, item) in items.enumerated() {
            item.order = i
        }
        return true
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

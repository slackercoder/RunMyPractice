import Foundation
import SwiftData

/// An executed instance of a Practice (v0.5.0: self-contained run record).
///
/// At run start the session **deep-copies the practice plan** (activities +
/// drills) into its own `activities`, and snapshots its participating groups
/// as plain values (see `PracticeSessionTeam`). Editing or deleting the
/// practice template or roster after a run begins therefore never rewrites
/// or destroys recorded runs: the template stays freely editable and
/// shareable (other coaches can run it with their own groups), while each
/// recorded run keeps exactly the plan it was run with.
///
/// `practice` is kept as a provenance reference to the template (and for
/// resume matching) — all execution read/display logic uses the snapshot.
@Model
final class PracticeSession {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    @Relationship var practice: Practice?
    var createdBy: String?
    var createDate: Date

    /// The practice's title frozen at run start — the template may be renamed
    /// later, but a recorded run keeps the name it was run under.
    var practiceTitle: String?

    /// Frozen copy of the practice plan at run start. These are detached
    /// `Activity`/`Drill` instances (fresh IDs, copied fields) that nothing
    /// but this session references — the template's own activities live on
    /// `Practice.activities`. The same types are reused so the execute view
    /// needs no new model types.
    @Relationship(deleteRule: .cascade) var activities: [Activity] = []

    @Relationship(deleteRule: .cascade) var sessionTeams: [PracticeSessionTeam] = []
    @Relationship(deleteRule: .cascade) var acknowledgements: [DrillAcknowledgement] = []

    /// True once the sync worker has pushed this session and the server
    /// confirmed the records (and backfilled the `remoteId`s).
    var isSynced: Bool = false

    /// Set when the coach finishes the run (Finish → Save & Exit, v0.6.0).
    /// Nil = in progress. Resume (`Practice.currentSession`) only matches
    /// incomplete, unsynced sessions, so a finished run never resurfaces on
    /// the next "Execute Practice" — the same template can be run over and
    /// over, with each run reviewable separately.
    var completedDate: Date?

    init(practice: Practice?, createdBy: String? = nil) {
        self.id = UUID()
        self.practice = practice
        self.createdBy = createdBy
        self.createDate = Date()
    }

    /// The frozen plan in intended run order.
    var orderedActivities: [Activity] {
        activities.sorted { $0.order < $1.order }
    }

    /// The single creation choke point: creates a new session for the
    /// practice, deep-copies the plan (fresh IDs, copied fields, `remoteId`
    /// always nil — the sync worker backfills them), and saves.
    ///
    /// Resume never calls this — it returns the existing session, so a plan
    /// edited mid-break is never re-snapshotted into a half-finished run.
    ///
    /// Throws if the session could not be persisted: the caller must surface
    /// the error instead of presenting a session that exists only in memory
    /// (and would be lost if the app is force-quit mid-run).
    static func start(for practice: Practice, in context: ModelContext) throws -> PracticeSession {
        let session = PracticeSession(practice: practice)
        session.practiceTitle = practice.title

        for activity in practice.orderedActivities {
            let copy = Activity(
                title: activity.title,
                activityDescription: activity.activityDescription,
                timeAllottedInMinutes: activity.timeAllottedInMinutes,
                order: activity.order,
                createdBy: activity.createdBy
            )
            for drill in activity.orderedDrills {
                let drillCopy = Drill(
                    title: drill.title,
                    drillDescription: drill.drillDescription,
                    notes: drill.notes,
                    runNotes: nil, // each run journals its own field notes (v0.9.1)
                    isScored: drill.isScored,
                    maxPoints: drill.maxPoints,
                    pointStep: drill.pointStep,
                    isCoachDrill: drill.isCoachDrill,
                    order: drill.order,
                    createdBy: drill.createdBy
                )
                drillCopy.isAcknowledged = drill.isAcknowledged
                context.insert(drillCopy)
                copy.drills.append(drillCopy)
            }
            context.insert(copy)
            session.activities.append(copy)
        }

        context.insert(session)
        try context.save()
        return session
    }
}

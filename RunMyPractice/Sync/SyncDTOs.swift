import Foundation

/// Wire types for the Practice sync API (Technical Spec §6) — the Swift mirror
/// of the C# records in `Practice.Contracts` (runmy repo).
///
/// Property names deliberately match the server's camelCase JSON exactly, so
/// no `CodingKeys` are needed. Every request record carries the
/// client-generated UUID (`id`) so the server can respond with
/// `id → remoteId` dictionaries for backfill (Section 4.1's dual-key
/// strategy). The server scopes everything to the `X-Coach-Id` header and
/// treats each sync as the coach's *complete current state* (upsert =
/// replace), which is why the DTOs carry no ownership field.

// MARK: - Practices

/// One practice template of a practices sync batch.
struct SyncPracticesRequest: Codable {
    var id: UUID
    var title: String
    var createDate: Date
    var activities: [SyncActivityRequest]

    init(_ practice: Practice) {
        id = practice.id
        title = practice.title
        createDate = practice.createDate
        activities = practice.orderedActivities.map(SyncActivityRequest.init)
    }
}

/// One activity of a practice template, or of a session's frozen plan
/// snapshot — the same shape is reused for both sync endpoints.
struct SyncActivityRequest: Codable {
    var id: UUID
    var title: String
    var description: String?
    var timeAllottedInMinutes: Int
    var order: Int
    var createDate: Date
    var drills: [SyncDrillRequest]

    init(_ activity: Activity) {
        id = activity.id
        title = activity.title
        description = activity.activityDescription
        timeAllottedInMinutes = activity.timeAllottedInMinutes
        order = activity.order
        createDate = activity.createDate
        drills = activity.orderedDrills.map(SyncDrillRequest.init)
    }
}

/// One drill of a practice template, or of a session's frozen plan snapshot.
/// `runNotes` is only ever set on session snapshots (the coach's field
/// journal for one run); template drills keep it nil.
struct SyncDrillRequest: Codable {
    var id: UUID
    var title: String
    var description: String?
    var notes: String?
    var runNotes: String?
    var isScored: Bool
    var isAcknowledged: Bool
    var maxPoints: Int?
    var pointStep: Int?
    var isCoachDrill: Bool
    var order: Int
    var createDate: Date

    init(_ drill: Drill) {
        id = drill.id
        title = drill.title
        description = drill.drillDescription
        notes = drill.notes
        runNotes = drill.runNotes
        isScored = drill.isScored
        isAcknowledged = drill.isAcknowledged
        maxPoints = drill.maxPoints
        pointStep = drill.pointStep
        isCoachDrill = drill.isCoachDrill
        order = drill.order
        createDate = drill.createDate
    }
}

// MARK: - Drill library

/// One entry of the coach's standalone drill library (v0.12.0). No `order`
/// (library entries are unordered) and no `runNotes` (run-only).
struct SyncDrillLibraryRequest: Codable {
    var id: UUID
    var title: String
    var description: String?
    var notes: String?
    var isScored: Bool
    var maxPoints: Int?
    var pointStep: Int?
    var isCoachDrill: Bool
    var createDate: Date

    init(_ entry: DrillLibrary) {
        id = entry.id
        title = entry.title
        description = entry.drillDescription
        notes = entry.notes
        isScored = entry.isScored
        maxPoints = entry.maxPoints
        pointStep = entry.pointStep
        isCoachDrill = entry.isCoachDrill
        createDate = entry.createDate
    }
}

// MARK: - Sessions

/// A completed run's score for one (snapshot) drill by one participating group.
/// `drillId` is the client UUID of the session's own snapshot drill.
struct SyncScoreRequest: Codable {
    var id: UUID
    var drillId: UUID
    var score: Int
    var createDate: Date

    init(_ score: TeamScore, drill: Drill) {
        id = score.id
        drillId = drill.id
        self.score = score.score
        createDate = score.createDate
    }
}

/// One participating group of a run, as frozen values. A solo participant is
/// a values-only "team of 1" (`teamId` nil, the player's label in
/// `playerLabels`). `createDate` is always nil — the client's team model has
/// no create date; the server falls back to the session's.
struct SyncSessionTeamRequest: Codable {
    var id: UUID
    var teamId: UUID?
    var teamName: String
    var playerLabels: [String]?
    var createDate: Date?
    var soloPlayerId: UUID?
    var scores: [SyncScoreRequest]

    init(_ team: PracticeSessionTeam) {
        id = team.id
        teamId = team.sourceTeamID
        teamName = team.teamName
        playerLabels = team.playerLabels
        createDate = nil
        soloPlayerId = team.soloPlayerID
        // A score whose drill snapshot is somehow missing can't be
        // referenced by UUID — skip it rather than fail the whole run.
        scores = team.scores.compactMap { score in
            score.drill.map { SyncScoreRequest(score, drill: $0) }
        }
    }
}

/// The acknowledged state of one unscored drill of a run.
struct SyncAcknowledgementRequest: Codable {
    var id: UUID
    var drillId: UUID
    var isAcknowledged: Bool
    var createDate: Date

    init(_ acknowledgement: DrillAcknowledgement, drill: Drill) {
        id = acknowledgement.id
        drillId = drill.id
        isAcknowledged = acknowledgement.isAcknowledged
        createDate = acknowledgement.createDate
    }
}

/// One completed run: the session, its frozen plan snapshot, participating
/// groups, and execution data — self-contained (v0.5.0). `practiceId` is
/// provenance-only.
struct SyncSessionRequest: Codable {
    var id: UUID
    var practiceId: UUID?
    var practiceTitle: String?
    var createDate: Date
    var completedDate: Date?
    var activities: [SyncActivityRequest]
    var sessionTeams: [SyncSessionTeamRequest]
    var acknowledgements: [SyncAcknowledgementRequest]

    init(_ session: PracticeSession) {
        id = session.id
        practiceId = session.practice?.id
        practiceTitle = session.practiceTitle
        createDate = session.createDate
        completedDate = session.completedDate
        activities = session.orderedActivities.map(SyncActivityRequest.init)
        sessionTeams = session.sessionTeams.map(SyncSessionTeamRequest.init)
        acknowledgements = session.acknowledgements.compactMap { acknowledgement in
            acknowledgement.drill.map { SyncAcknowledgementRequest(acknowledgement, drill: $0) }
        }
    }
}

// MARK: - Responses

/// Client UUID → server identity for every record persisted by a practices
/// sync, so the client can backfill `remoteId`.
struct SyncPracticesResponse: Codable {
    var practices: [UUID: Int]
    var activities: [UUID: Int]
    var drills: [UUID: Int]
}

/// Client UUID → server identity for every library drill persisted by a
/// drill-library sync.
struct SyncDrillLibrariesResponse: Codable {
    var drillLibraries: [UUID: Int]
}

/// Client UUID → server identity for every record persisted by a sessions
/// sync: the session, its frozen plan snapshot, groups, scores, and
/// acknowledgements.
struct SyncSessionsResponse: Codable {
    var sessions: [UUID: Int]
    var activities: [UUID: Int]
    var drills: [UUID: Int]
    var sessionTeams: [UUID: Int]
    var scores: [UUID: Int]
    var acknowledgements: [UUID: Int]
}

# Technical Specification Document: Practice Tracking Application

## 1. Document Metadata & Changelog
* **Author(s):** [Your Name]
* **Status:** Draft
* **Date:** September 10, 2026
* **Version:** 1.5.0

| Version | Date | Description | Author |
| :--- | :--- | :--- | :--- |
| 1.0.0 | 2026-09-10 | Initial Core Architecture Draft | [Name] |
| 1.1.0 | 2026-09-10 | Refined Activity, Drill, and Scoring Logic | [Name] |
| 1.2.0 | 2026-09-10 | Replaced backend schema with Practice/PracticeSession model; updated SwiftData models (4.1) and sync payload (6) to match | [Name] |
| 1.3.0 | 2026-09-14 | v0.5.0: self-contained run records — sessions snapshot the plan + group at run start (4.1, 4.2, 6, 7 updated) | [Name] |

| 1.4.0 | 2026-09-20 | v0.6.0: drill `notes` field, session `completedDate` (resume matches only incomplete runs), run history & review UI — Runs tab, read-only run review, per-practice past runs (4.1, 4.2, 5 updated) | [Name] |
| 1.5.0 | 2026-09-20 | v0.7.0: player standings — per-player point totals computed from recorded runs (team + solo scores), one-way StandingsReset marker for resets; v0.6.1 navigation fixes (nested stack removed, destinations hoisted) | [Name] |

---

## 2. System Architecture & High-Level Design
* **Architectural Pattern:** Offline-First Client/Server architecture. 
* **Client Architecture:** MVVM (Model-View-ViewModel) using SwiftUI and SwiftData for unified local state management.
* **Sync Strategy:** The local SwiftData container acts as the single source of truth for the user interface. A local background worker monitors network availability and manages an idempotent, unidirectional (push-only) queue to transmit structural practice records to a `.NET Web API`.
* **Data Privacy Boundaries:** Zero PII storage. Athletes are assigned unique strings (e.g., nicknames, position codes like "Lead A", or random numbers) configured directly by the coach. 

---

## 3. Technology Stack
* **Frontend Mobile (Initial Target):** iOS / iPadOS via native SwiftUI.
* **Local Database Store:** SwiftData framework (backed by a localized SQLite storage sandbox).
* **Remote Backend API:** .NET Web API (C#) extended with sync endpoints.
* **Remote Database Store:** SQL Server relational schema mapping.
* **Future Expansion Targets:** Android (Kotlin Multiplatform or Flutter) and Web frontends mapping back to the same schema boundaries.

---

## 4. Generalized Data Models & Architectural Strategy
To ensure the application can scale from curling to any other sporting discipline, sports-specific entities are abstracted into four explicit hierarchies: 
`Sessions ➔ Activities (Segments) ➔ Drills ➔ Teams`.

### Individual vs. Team Drill Simplification
To avoid complex relational data configurations or polymorphism when handling individual versus team drills, **all drills are evaluated using a Team context**. For individual drills, the session records a values-only "team of 1" participant row (the player's label, Section 4.1) — no roster `Team` record is provisioned in the app; the one-person team is materialized server-side when the session syncs (Section 6).

### 4.1 Client-Side SwiftData Models
Every model carries a client-generated `id: UUID` as its local identity (required for offline-first creation) plus an optional `remoteId: Int?` that is populated once the server assigns its `INT IDENTITY` primary key on first successful sync. Records with `remoteId == nil` are treated as not-yet-created server-side; the sync worker upserts by `id` and stores the returned `remoteId`.

```swift
import Foundation
import SwiftData

// A reusable template: a named practice plan made up of Activities/Drills.
@Model
final class Practice {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var title: String
    var createdBy: String?
    var createDate: Date
    @Relationship var activities: [Activity] = [] // maps to PracticeActivity join rows on sync

    init(title: String, createdBy: String? = nil) {
        self.id = UUID()
        self.title = title
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var title: String // E.g., "Warm-up", "End-Game Scenarios"
    var activityDescription: String?
    var timeAllottedInMinutes: Int
    var order: Int
    var createdBy: String?
    var createDate: Date
    // Flattens the backend's DrillList indirection layer; a DrillList row is
    // created/matched 1:1 for this Activity at sync time.
    @Relationship(deleteRule: .cascade) var drills: [Drill] = []

    init(title: String, activityDescription: String? = nil, timeAllottedInMinutes: Int, order: Int, createdBy: String? = nil) {
        self.id = UUID()
        self.title = title
        self.activityDescription = activityDescription
        self.timeAllottedInMinutes = timeAllottedInMinutes
        self.order = order
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

@Model
final class Drill {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var title: String // E.g., "Progressive Slides", "Draw to the Button"
    var drillDescription: String?
    var notes: String? // Coach notes (v0.6.0): setup, cues, what to watch for

    // Scoring Configuration Engine
    var isScored: Bool // False = Acknowledgement check-box only
    var isAcknowledged: Bool // Default/template flag; per-session state lives on DrillAcknowledgement
    var maxPoints: Int? // E.g., 10
    var pointStep: Int? // E.g., 2 -> UI renders choice matrix: [0, 2, 4, 6, 8, 10]
    var isCoachDrill: Bool // Coach-only drill, hidden from athlete-facing views
    var order: Int
    var createdBy: String?
    var createDate: Date

    init(title: String, drillDescription: String? = nil, notes: String? = nil, isScored: Bool, maxPoints: Int? = nil, pointStep: Int? = nil, isCoachDrill: Bool = false, order: Int, createdBy: String? = nil) {
        self.id = UUID()
        self.title = title
        self.drillDescription = drillDescription
        self.notes = notes
        self.isScored = isScored
        self.isAcknowledged = false
        self.maxPoints = maxPoints
        self.pointStep = pointStep
        self.isCoachDrill = isCoachDrill
        self.order = order
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

@Model
final class Team {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var teamName: String // E.g., "Team 1" or background-generated fallback for individuals
    @Relationship var players: [Player] = []

    init(teamName: String, players: [Player] = []) {
        self.id = UUID()
        self.teamName = teamName
        self.players = players
    }
}

@Model
final class Player {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var playerName: String // E.g., "Skip A", "Lead", "Player 1"
    var createdBy: String?
    var createDate: Date

    init(playerName: String, createdBy: String? = nil) {
        self.id = UUID()
        self.playerName = playerName
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

// An executed instance of a Practice (v0.5.0: self-contained run record).
// It snapshots the plan (activities + drills) and the participating group
// (values) at run start, so editing/deleting the template or roster later
// never rewrites or destroys recorded runs. `practice` is provenance-only.
@Model
final class PracticeSession {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    @Relationship var practice: Practice?
    /// Frozen practice title (the template may be renamed later).
    var practiceTitle: String?
    var createdBy: String?
    var createDate: Date
    /// Frozen copy of the plan at run start (detached Activities/Drills).
    @Relationship(deleteRule: .cascade) var activities: [Activity] = []
    @Relationship(deleteRule: .cascade) var sessionTeams: [PracticeSessionTeam] = []
    @Relationship(deleteRule: .cascade) var acknowledgements: [DrillAcknowledgement] = []
    var isSynced: Bool = false
    /// Set when the coach finishes the run (v0.6.0); nil = in progress.
    /// Resume matches only incomplete, unsynced sessions.
    var completedDate: Date?

    init(practice: Practice?, createdBy: String? = nil) {
        self.id = UUID()
        self.practice = practice
        self.createdBy = createdBy
        self.createDate = Date()
    }

    /// Single creation choke point: deep-copies the practice's plan (fresh
    /// IDs, copied fields) and saves. Resume never re-snapshots.
    static func start(for practice: Practice, in context: ModelContext) -> PracticeSession {
        let session = PracticeSession(practice: practice)
        session.practiceTitle = practice.title
        for activity in practice.orderedActivities {
            let copy = Activity(
                title: activity.title,
                timeAllottedInMinutes: activity.timeAllottedInMinutes,
                order: activity.order
            )
            for drill in activity.orderedDrills {
                let drillCopy = Drill(
                    title: drill.title,
                    notes: drill.notes,
                    isScored: drill.isScored,
                    maxPoints: drill.maxPoints,
                    pointStep: drill.pointStep,
                    order: drill.order
                )
                context.insert(drillCopy)
                copy.drills.append(drillCopy)
            }
            context.insert(copy)
            session.activities.append(copy)
        }
        context.insert(session)
        context.save()
        return session
    }
}

// A participating group in a session, snapshotted as values (v0.5.0).
// teamName/playerLabels are frozen when the group is enrolled; soloPlayerID
// and sourceTeamID are plain values for provenance/upsert (NOT relationships),
// so a deleted roster record never deletes or breaks a recorded run.
// Team scores hang off this row.
@Model
final class PracticeSessionTeam {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var teamName: String
    var playerLabels: [String] = []
    var soloPlayerID: UUID?
    var sourceTeamID: UUID?
    @Relationship(deleteRule: .cascade) var scores: [TeamScore] = []

    init(teamName: String, playerLabels: [String] = [], soloPlayerID: UUID? = nil, sourceTeamID: UUID? = nil) {
        self.id = UUID()
        self.teamName = teamName
        self.playerLabels = playerLabels
        self.soloPlayerID = soloPlayerID
        self.sourceTeamID = sourceTeamID
    }
}

@Model
final class TeamScore {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    @Relationship var drill: Drill?
    var score: Int
    var createdBy: String?
    var createDate: Date

    init(drill: Drill?, score: Int, createdBy: String? = nil) {
        self.id = UUID()
        self.drill = drill
        self.score = score
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

// Per-session, per-drill acknowledgement (unscored checkbox drills).
@Model
final class DrillAcknowledgement {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    @Relationship var drill: Drill?
    var isAcknowledged: Bool
    var createdBy: String?
    var createDate: Date

    init(drill: Drill?, isAcknowledged: Bool = true, createdBy: String? = nil) {
        self.id = UUID()
        self.drill = drill
        self.isAcknowledged = isAcknowledged
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

// One-way marker: the standings tally restarts from this point (v0.7.0).
// Player point totals are computed from recorded runs (their label on the
// scoring team), never stored — so a reset never deletes a run; it only
// stops runs from the latest reset onward from counting.
@Model
final class StandingsReset {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var date: Date
    var note: String? // e.g. "June league — prizes awarded"

    init(date: Date = Date(), note: String? = nil) {
        self.id = UUID()
        self.remoteId = nil
        self.date = date
        self.note = note
    }
}
```

### 4.2 Backend SQL Schema (.NET Target)

> Note: This schema separates a reusable **Practice** template (Activities/Drills defined once) from a **PracticeSession** (an executed instance of a Practice, tied to specific Teams). Scores and acknowledgements are recorded against the session/team/drill combination rather than nested under a single drill-execution record. See the callout at the end of this section for how this affects Sections 4.1 and 6.

```sql
CREATE TABLE Practice (
    PracticeId INT IDENTITY(1,1) PRIMARY KEY,
    Title NVARCHAR(150) NOT NULL,
    CreatedBy NVARCHAR(100) NULL, -- TODO: confirm GUID vs identifier string
    CreateDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE Activity (
    ActivityId INT IDENTITY(1,1) PRIMARY KEY,
    Title NVARCHAR(150) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    TimeAllottedInMinutes INT NOT NULL,
    [Order] INT NOT NULL,
    CreatedBy NVARCHAR(100) NOT NULL,
    CreateDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE PracticeActivity (
    PracticeActivityId INT IDENTITY(1,1) PRIMARY KEY,
    PracticeId INT NOT NULL FOREIGN KEY REFERENCES Practice(PracticeId),
    ActivityId INT NOT NULL FOREIGN KEY REFERENCES Activity(ActivityId)
);

CREATE TABLE DrillList (
    DrillListId INT IDENTITY(1,1) PRIMARY KEY,
    ActivityId INT NOT NULL FOREIGN KEY REFERENCES Activity(ActivityId)
);

CREATE TABLE Drill (
    DrillId INT IDENTITY(1,1) PRIMARY KEY,
    DrillListId INT NOT NULL FOREIGN KEY REFERENCES DrillList(DrillListId),
    Title NVARCHAR(150) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    Notes NVARCHAR(MAX) NULL,
    IsScored BIT NOT NULL DEFAULT 0,
    IsAcknowledged BIT NOT NULL DEFAULT 0,
    MaxPoints INT NULL,
    PointStep INT NULL,
    IsCoachDrill BIT NOT NULL DEFAULT 0,
    [Order] INT NOT NULL,
    CreatedBy NVARCHAR(100) NOT NULL,
    CreateDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE Team (
    TeamId INT IDENTITY(1,1) PRIMARY KEY,
    TeamName NVARCHAR(100) NOT NULL
);

CREATE TABLE Player (
    PlayerId INT IDENTITY(1,1) PRIMARY KEY,
    PlayerName NVARCHAR(100) NOT NULL,
    CreatedBy NVARCHAR(100) NOT NULL,
    CreateDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE TeamPlayer (
    TeamPlayerId INT IDENTITY(1,1) PRIMARY KEY,
    TeamId INT NOT NULL FOREIGN KEY REFERENCES Team(TeamId),
    PlayerId INT NOT NULL FOREIGN KEY REFERENCES Player(PlayerId)
);

CREATE TABLE PracticeSession (
    PracticeSessionId INT IDENTITY(1,1) PRIMARY KEY,
    PracticeId INT NOT NULL FOREIGN KEY REFERENCES Practice(PracticeId),
    CreatedBy NVARCHAR(100) NOT NULL,
    CreateDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CompletedDate DATETIME2 NULL, -- set on Finish; NULL = in progress (resume excludes completed)
);

CREATE TABLE PracticeSessionTeam (
    PracticeSessionTeamId INT IDENTITY(1,1) PRIMARY KEY,
    PracticeSessionId INT NOT NULL FOREIGN KEY REFERENCES PracticeSession(PracticeSessionId),
    TeamId INT NULL FOREIGN KEY REFERENCES Team(TeamId),
    TeamName NVARCHAR(100) NOT NULL,
    PlayerLabels NVARCHAR(MAX) NULL,
    SoloPlayerId INT NULL FOREIGN KEY REFERENCES Player(PlayerId)
);

CREATE TABLE TeamScore (
    TeamScoreId INT IDENTITY(1,1) PRIMARY KEY,
    PracticeSessionTeamId INT NOT NULL FOREIGN KEY REFERENCES PracticeSessionTeam(PracticeSessionTeamId),
    DrillId INT NOT NULL FOREIGN KEY REFERENCES Drill(DrillId),
    Score INT NOT NULL,
    CreatedBy NVARCHAR(100) NOT NULL,
    CreateDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE PracticeSessionAcknowledgement (
    PracticeSessionAcknowledgementId INT IDENTITY(1,1) PRIMARY KEY,
    PracticeSessionId INT NOT NULL FOREIGN KEY REFERENCES PracticeSession(PracticeSessionId),
    DrillId INT NOT NULL FOREIGN KEY REFERENCES Drill(DrillId),
    IsAcknowledged BIT NOT NULL DEFAULT 0,
    CreatedBy NVARCHAR(100) NOT NULL,
    CreateDate DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
```

> **Note:** Sections 4.1 and 6 have been updated to match this schema. Since the backend uses `INT IDENTITY` keys but the client must be able to create records offline, the client models carry a local `id: UUID` (client identity) plus an optional `remoteId: Int?` (server identity, populated after sync) — see Section 4.1 for details.

> **Note (v0.5.0):** `PracticeSessionTeam` stores the participating group as frozen values: `TeamName` is always present, `PlayerLabels` is a JSON array of coach-assigned labels, and `TeamId` / `SoloPlayerId` are nullable provenance/upsert keys rather than a hard `Team` foreign key — deleting a roster record must never break a recorded run. Solo participants ("teams of 1") materialize as a one-person `Team` row server-side at sync. The session's plan snapshot (Activities/Drills copied at run start) maps to session-scoped mirror rows keyed by `PracticeSessionId`; exact server-side snapshot storage is finalized in M6.
---

## 5. UI Elements & Dynamic Point Range Generation
When a drill configuration sets `isScored` to true, the UI calculates the point interval option grid via the step stride function logic:

```swift
/// Generates the numeric array needed to feed SwiftUI Pickers or Segmented Elements.
func generateScoreOptions(max: Int, step: Int) -> [Int] {
    stride(from: 0, through: max, by: step).map { $0 }
}
```

### Swift UI Interface Contexts
* **Ungraded Drill (`isScored == false`):** Renders a high-level list entry with an interactive toggle switch or checkbox. Toggling it creates (or updates) a `DrillAcknowledgement` record scoped to the current `PracticeSession` and this `Drill`, rather than mutating a flag on the drill itself.
* **Graded Drill (`isScored == true`):** Loops through the `PracticeSessionTeam` entries for the current session. Renders an adaptive grid item or selector containing the generated integer increments from the step calculations; a selection creates/updates a `TeamScore` record linking that team, the drill, and the chosen score.
* **Coach Notes (v0.6.0):** Each drill card renders the drill's `notes` (coach setup/cue text) under the description in the practice detail view and the live execute screen; a finished run's read-only review shows the notes as snapshotted at run time.
* **Player Standings (v0.7.0):** The Players tab renders each player's current points total — every point a team they were on scored, plus solo scores, from runs after the latest `StandingsReset` marker — with sort by label or by points (leaderboard) and a one-tap reset (optional note).

---

## 6. API Design & Core Sync Payload
### Push Sync Endpoint: POST `/api/v1/sync/sessions`
Accepts hierarchical payload components to persist completed session records. Since v0.5.0 the session payload is **self-contained**: because `Practice` is a freely editable and shareable template, the payload embeds the session's frozen plan snapshot — `activities` with their `drills`, copied at run start under fresh client UUIDs and stored server-side as session-scoped rows — plus the participating group as values (`sessionTeams[].teamName` + `playerLabels`; a solo participant is a values-only "team of 1"). The *execution* data (per-participant scores and acknowledgements) references the snapshot drills by `id`, not the template's. `practiceId` is provenance-only. All `id` values are client-generated UUIDs; a `remoteId` is absent until the server has persisted the record and returned its assigned identity (see Section 4.1).

#### Request Body Example
```json
[
  {
    "id": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "practiceId": "11111111-2222-3333-4444-555555555555",
    "practiceTitle": "Curling Fundamentals",
    "createdBy": "coach_jsmith",
    "createDate": "2026-09-10T11:45:00-04:00",
    "activities": [
      {
        "id": "7c8d9e0f-1a2b-3c4d-5e6f-7a8b9c0d1e2f",
        "title": "Ice Warm-up",
        "timeAllottedInMinutes": 15,
        "order": 0,
        "drills": [
          {
            "id": "d4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a",
            "title": "Progressive Slides",
            "isScored": false,
            "order": 0
          }
        ]
      },
      {
        "id": "8d9e0f1a-2b3c-4d5e-6f7a-8b9c0d1e2f3a",
        "title": "Draw to Button Accuracy",
        "timeAllottedInMinutes": 20,
        "order": 1,
        "drills": [
          {
            "id": "e5f6a7b8-c9d0-1e2f-3a4b-5c6d7e8f9a0b",
            "title": "Draw Placement",
            "isScored": true,
            "maxPoints": 10,
            "pointStep": 2,
            "order": 0
          }
        ]
      }
    ],
    "sessionTeams": [
      {
        "id": "b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e",
        "teamId": "00000000-1111-2222-3333-444455556666",
        "teamName": "Team 1",
        "playerLabels": ["Skip A", "Lead B"],
        "soloPlayerId": null,
        "scores": [
          {
            "id": "f6a7b8c9-d0e1-2f3a-4b5c-6d7e8f9a0b1c",
            "drillId": "e5f6a7b8-c9d0-1e2f-3a4b-5c6d7e8f9a0b",
            "score": 8,
            "createdBy": "coach_jsmith",
            "createDate": "2026-09-10T12:05:00-04:00"
          }
        ]
      },
      {
        "id": "9a8b7c6d-5e4f-3a2b-1c0d-0f1e2d3c4b5a",
        "teamId": null,
        "teamName": "Skip C",
        "playerLabels": ["Skip C"],
        "soloPlayerId": "34343434-4545-5656-6767-787878787878",
        "scores": [
          {
            "id": "0f1e2d3c-4b5a-6c7d-8e9f-0a1b2c3d4e5f",
            "drillId": "e5f6a7b8-c9d0-1e2f-3a4b-5c6d7e8f9a0b",
            "score": 6,
            "createdBy": "coach_jsmith",
            "createDate": "2026-09-10T12:05:00-04:00"
          }
        ]
      }
    ],
    "acknowledgements": [
      {
        "id": "c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f",
        "drillId": "d4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a",
        "isAcknowledged": true,
        "createdBy": "coach_jsmith",
        "createDate": "2026-09-10T11:50:00-04:00"
      }
    ]
  }
]
```

In this example, `practiceId` points at the "Curling Fundamentals" `Practice` template; `activities` is the session's **frozen snapshot** of that plan (copied at run start, so later template edits never affect this record), and the `drillId` values in `sessionTeams[].scores` / `acknowledgements` reference the *snapshot* drills (the unscored "Progressive Slides" in "Ice Warm-up"; the scored "Draw Placement" in "Draw to Button Accuracy"). The first `sessionTeams` entry is a named team (`teamId` is its source roster team; `teamName` + `playerLabels` are the frozen values); the second is a solo participant — a values-only "team of 1" (`teamId` null until the server materializes the one-person team, `soloPlayerId` identifying the roster player).

#### Response
The server responds with the `id` → `remoteId` mapping for every record it persisted (session, session-teams, scores, acknowledgements), so the client can populate `remoteId` locally and mark the session `isSynced = true`.

---

## 7. Risks, Constraints, and Assumptions
* **Dual-Key Sync Strategy:** Because the backend uses `INT IDENTITY` primary keys while the offline-first client must create valid local records without network access, every synced entity carries both a client-generated `id: UUID` and a server-assigned `remoteId: Int?`. The sync layer must upsert by `id` and backfill `remoteId` from the server's response; any endpoint or query that assumes a single canonical key (e.g. deep links, push notification payloads referencing a record) needs to standardize on `id` until sync completes.
* **Practice/Template Editing — resolved (v0.5.0):** Sessions snapshot the plan (activities + drills) and the participating group (as values) at run start, so editing or deleting a `Practice` template, or a roster team/player, after sessions have run never rewrites or destroys recorded runs. The session's `practice` reference and `PracticeSessionTeam.sourceTeamID`/`soloPlayerID` are provenance-only plain values. Remaining work: server-side storage of the plan snapshot (Section 6), finalized in M6.
* **Ownership and sharing:** Roster records (players, teams) are private to the coach who created them (`createdBy` is the local ownership anchor; they become scoped to the signed-in user once auth lands). Practices are shareable templates — another coach can import a practice and run it with their own groups. Sessions are private run records; the payload carries group *labels* (not just IDs), so a cross-user run needs no roster ID resolution.

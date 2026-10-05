import Foundation
import SwiftData

/// A reusable drill stored in the coach's library (v0.12.0) — a drill kept
/// **separately from any practice**, so it can be built once and dropped into
/// any activity.
///
/// This is the standalone home of a drill's template fields (title,
/// description, notes, scoring configuration, coach-only visibility). It has
/// deliberately **no `order`** (library entries are unordered — position only
/// exists *inside* an activity) and **no `runNotes`** (field notes belong to
/// executed runs only, v0.9.1).
///
/// **Copy, never reference** (the same rule activities follow, v0.10.0):
/// adding a library drill to an activity copies it into a `Drill` with a
/// fresh client UUID. The copy and the library entry are independent
/// records from that moment on — editing one never touches the other, so a
/// library drill is a *starting point*, and practices stay self-contained
/// templates (Technical Spec §2).
///
/// Sync (M6): upserted coach-scoped by client UUID via
/// `POST /api/v1/sync/drill-libraries`; `remoteId` is the server-assigned
/// identity, backfilled after the response.
@Model
final class DrillLibrary {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var title: String // E.g., "Progressive Slides", "Draw to the Button"
    var drillDescription: String?
    var notes: String? // Coach notes: setup, cues, what to watch for
    var isScored: Bool // false = acknowledgement check-box only
    var maxPoints: Int? // E.g., 10
    var pointStep: Int? // E.g., 2 -> UI renders choice matrix: [0, 2, 4, 6, 8, 10]
    var isCoachDrill: Bool // Coach-only drill, hidden from athlete-facing views
    var createdBy: String?
    var createDate: Date

    init(
        title: String,
        drillDescription: String? = nil,
        notes: String? = nil,
        isScored: Bool,
        maxPoints: Int? = nil,
        pointStep: Int? = nil,
        isCoachDrill: Bool = false,
        createdBy: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.drillDescription = drillDescription
        self.notes = notes
        self.isScored = isScored
        self.maxPoints = maxPoints
        self.pointStep = pointStep
        self.isCoachDrill = isCoachDrill
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

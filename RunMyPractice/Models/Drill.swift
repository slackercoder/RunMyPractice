import Foundation
import SwiftData

/// The atomic unit of a practice: a named exercise.
///
/// Individual vs. team drills (Technical Spec §4): all drills are evaluated in
/// a Team context; for individual drills the app transparently provisions a
/// "Team of 1" in the background.
@Model
final class Drill {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var title: String // E.g., "Progressive Slides", "Draw to the Button"
    var drillDescription: String?
    /// Coach notes on the drill (v0.6.0): setup, cues, what to watch for.
    /// Free text, shown in the drill form, during execution, and in run reviews.
    var notes: String?

    // Scoring configuration engine.
    var isScored: Bool // false = acknowledgement check-box only
    var isAcknowledged: Bool // template default flag; per-session state lives on DrillAcknowledgement
    var maxPoints: Int? // E.g., 10
    var pointStep: Int? // E.g., 2 -> UI renders choice matrix: [0, 2, 4, 6, 8, 10]
    var isCoachDrill: Bool // Coach-only drill, hidden from athlete-facing views
    var order: Int
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
        order: Int,
        createdBy: String? = nil
    ) {
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

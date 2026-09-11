import Foundation
import SwiftData

/// A named segment of a practice (e.g. "Warm-up", "End-Game Scenarios").
/// Activities are ordered by `order` and contain the drills that make them up.
@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var title: String
    var activityDescription: String?
    var timeAllottedInMinutes: Int
    var order: Int
    var createdBy: String?
    var createDate: Date

    /// Flattens the backend's DrillList indirection layer; a DrillList row is
    /// created/matched 1:1 for this Activity at sync time.
    @Relationship(deleteRule: .cascade) var drills: [Drill] = []

    init(
        title: String,
        activityDescription: String? = nil,
        timeAllottedInMinutes: Int,
        order: Int,
        createdBy: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.activityDescription = activityDescription
        self.timeAllottedInMinutes = timeAllottedInMinutes
        self.order = order
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

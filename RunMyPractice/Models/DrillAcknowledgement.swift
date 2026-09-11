import Foundation
import SwiftData

/// Per-session acknowledgement for an unscored (`isScored == false`) drill.
/// Toggling the checkbox in the execute view creates/updates this record
/// scoped to the current PracticeSession — the template Drill itself is never
/// mutated by session state.
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

import Foundation
import SwiftData

/// A reusable template: a named practice plan made up of Activities/Drills.
///
/// Dual-key sync strategy (Technical Spec §7): every record carries a
/// client-generated `id` (local identity, created fully offline) plus an
/// optional `remoteId` that the server assigns on first successful sync.
/// `remoteId == nil` means the record has not been persisted server-side yet.
@Model
final class Practice {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var title: String
    var createdBy: String?
    var createDate: Date

    /// Maps to PracticeActivity join rows on sync.
    @Relationship var activities: [Activity] = []

    init(title: String, createdBy: String? = nil) {
        self.id = UUID()
        self.title = title
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

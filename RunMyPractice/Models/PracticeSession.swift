import Foundation
import SwiftData

/// An executed instance of a Practice, run against one or more Teams.
/// Created on the day of the practice; this is the execution record that the
/// sync layer pushes to the server (Technical Spec §6).
@Model
final class PracticeSession {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    @Relationship var practice: Practice?
    var createdBy: String?
    var createDate: Date

    @Relationship(deleteRule: .cascade) var sessionTeams: [PracticeSessionTeam] = []
    @Relationship(deleteRule: .cascade) var acknowledgements: [DrillAcknowledgement] = []

    /// True once the sync worker has pushed this session and the server
    /// confirmed the records (and backfilled the `remoteId`s).
    var isSynced: Bool = false

    init(practice: Practice?, createdBy: String? = nil) {
        self.id = UUID()
        self.practice = practice
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

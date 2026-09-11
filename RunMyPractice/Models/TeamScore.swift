import Foundation
import SwiftData

/// A score recorded for one drill by one team during a session. Lives under
/// the PracticeSessionTeam for that session; the drill is the template record
/// being scored.
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

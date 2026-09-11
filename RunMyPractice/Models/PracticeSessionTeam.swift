import Foundation
import SwiftData

/// Join between a PracticeSession and a participating Team. Team scores for
/// the session hang off this record.
@Model
final class PracticeSessionTeam {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    @Relationship var team: Team?
    @Relationship(deleteRule: .cascade) var scores: [TeamScore] = []

    init(team: Team?) {
        self.id = UUID()
        self.team = team
    }
}

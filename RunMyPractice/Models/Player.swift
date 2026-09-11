import Foundation
import SwiftData

/// A player/athlete. Zero PII by design (Technical Spec §2): the coach assigns
/// a non-identifying label (e.g. "Skip A", "Lead", a random code).
@Model
final class Player {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var playerName: String
    var createdBy: String?
    var createDate: Date

    init(playerName: String, createdBy: String? = nil) {
        self.id = UUID()
        self.playerName = playerName
        self.createdBy = createdBy
        self.createDate = Date()
    }
}

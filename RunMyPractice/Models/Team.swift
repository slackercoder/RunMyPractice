import Foundation
import SwiftData

/// A named group of players (e.g. "Team 1"). For individual drills the app
/// transparently provisions a "Team of 1" in the background.
@Model
final class Team {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var teamName: String
    @Relationship var players: [Player] = []

    init(teamName: String, players: [Player] = []) {
        self.id = UUID()
        self.teamName = teamName
        self.players = players
    }
}

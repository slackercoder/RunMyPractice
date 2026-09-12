import Foundation
import SwiftData
import Observation

/// MVVM form model for creating a player (roster, Functional Spec §5.5).
///
/// Players are zero-PII coach-assigned labels (Technical Spec §2). The draft
/// is a single name field, validated against duplicates.
///
/// When created from the execute screen's participant sheet (`session != nil`),
/// the new player is immediately enrolled in that session as a solo
/// participant — the "team of 1" is provisioned in the background
/// (Technical Spec §4), so the coach never has to leave the practice screen.
@Observable
final class PlayerFormViewModel: Identifiable {
    let id = UUID()
    let session: PracticeSession?

    var name = ""
    var existingPlayerNames: [String] = []

    init(session: PracticeSession? = nil) {
        self.session = session
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var duplicateName: Bool {
        existingPlayerNames.contains { $0.caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    var isValid: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 30 && !duplicateName
    }

    var validationMessage: String? {
        if trimmedName.isEmpty { return "Enter a player label." }
        if trimmedName.count > 30 { return "Labels must be 30 characters or fewer." }
        if duplicateName { return "There's already a player with that label." }
        return nil
    }

    /// Creates the player. When attached to a session, also enrolls the new
    /// player as a solo participant. Returns the created player.
    @discardableResult
    func save(in context: ModelContext) -> Player? {
        guard isValid else { return nil }
        let player = Player(playerName: trimmedName)
        context.insert(player)

        if let session {
            let teams = (try? context.fetch(FetchDescriptor<Team>())) ?? []
            var team = teams.first { $0.teamName == player.playerName && $0.players.isEmpty }
            if team == nil {
                let newTeam = Team(teamName: player.playerName)
                context.insert(newTeam)
                team = newTeam
            }
            team?.players.append(player)
            let sessionTeam = PracticeSessionTeam(team: team)
            context.insert(sessionTeam)
            session.sessionTeams.append(sessionTeam)
        }

        try? context.save()
        return player
    }
}

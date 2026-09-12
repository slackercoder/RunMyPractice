import Foundation
import SwiftData
import Observation

/// MVVM form model for the participant setup sheet during a session (M4).
///
/// During a practice, participants run the drills:
/// - **Named teams** — free-form names (e.g. "Team 1") stored as `Team` records.
/// - **Solo players** — the app transparently provisions a "Team of 1" in the
///   background (Technical Spec §4: every drill is evaluated in a Team context;
///   individuals need no extra layout).
///
/// The draft (new team name, selected players) is written to the session
/// only on Save, so Cancel cleanly discards it. Nothing is pre-created:
/// score/check-off records are created on first interaction in the execute view.
@Observable
final class TeamSetupViewModel {
    let session: PracticeSession

    var newTeamName = ""
    var selectedPlayerIds: Set<UUID> = []

    init(session: PracticeSession, in context: ModelContext) {
        self.session = session
        refreshSelections()
    }

    /// Re-read the session's current participants so the sheet reflects state
    /// changed elsewhere (e.g. a player added in a nested sheet this visit).
    func refreshSelections() {
        var ids: Set<UUID> = []
        for sessionTeam in session.sessionTeams {
            if let playerID = Self.soloPlayerID(of: sessionTeam) {
                ids.insert(playerID)
            }
        }
        selectedPlayerIds = ids
    }

    /// Session teams whose team has exactly one player (provisioned "team of 1").
    var soloTeams: [PracticeSessionTeam] {
        session.sessionTeams.filter { $0.team?.players.count == 1 }
    }

    /// Session teams that are actual named teams (not provisioned teams of 1).
    var namedTeams: [PracticeSessionTeam] {
        session.sessionTeams.filter { ($0.team?.players.count ?? 0) != 1 }
    }

    var trimmedNewTeamName: String {
        newTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canAddTeam: Bool {
        !trimmedNewTeamName.isEmpty && trimmedNewTeamName.count <= 50
    }

    var validationMessage: String? {
        if newTeamName.count > 50 { return "Team name must be 50 characters or fewer." }
        return nil
    }

    var isValid: Bool {
        newTeamName.count <= 50
    }

    func isPlayerSelected(_ player: Player) -> Bool {
        selectedPlayerIds.contains(player.id)
    }

    func togglePlayer(_ player: Player) {
        if selectedPlayerIds.contains(player.id) {
            selectedPlayerIds.remove(player.id)
        } else {
            selectedPlayerIds.insert(player.id)
        }
    }

    /// Creates a new roster player right here (no need to leave the practice
    /// screen) and enrolls them in this session as a solo participant.
    @discardableResult
    func addPlayer(named playerName: String, in context: ModelContext) -> Player? {
        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 30 else { return nil }
        let all = (try? context.fetch(FetchDescriptor<Player>())) ?? []
        guard !all.contains(where: { $0.playerName.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
        let player = Player(playerName: name)
        context.insert(player)
        let team = soloTeam(for: player, in: context)
        let sessionTeam = PracticeSessionTeam(team: team)
        context.insert(sessionTeam)
        session.sessionTeams.append(sessionTeam)
        selectedPlayerIds.insert(player.id)
        try? context.save()
        return player
    }

    /// Deletes a roster player, its provisioned solo team, and its session
    /// participant entries (see `Player.delete(in:)`).
    func deletePlayer(_ player: Player, in context: ModelContext) {
        player.delete(in: context)
        selectedPlayerIds.remove(player.id)
        try? context.save()
    }

    /// Unlinks and deletes a named team from the session immediately (the
    /// sheet reads the live session). Cancel = `context.rollback()`, which
    /// restores it; Save persists the removal by keeping it deleted.
    func removeNamedTeam(_ sessionTeam: PracticeSessionTeam, in context: ModelContext) {
        context.delete(sessionTeam)
        session.sessionTeams.removeAll { $0.id == sessionTeam.id }
    }

    /// Writes the draft to the session: removes dropped solo players, adds the
    /// new named team, and provisions "teams of 1" for newly selected players.
    /// Provisioned solo teams are found-or-created so they can be reused by
    /// later sessions (the template `Team` record survives session discard).
    func save(in context: ModelContext) {
        guard isValid else { return }

        for sessionTeam in session.sessionTeams {
            let wanted: Bool
            if let soloID = Self.soloPlayerID(of: sessionTeam) {
                wanted = selectedPlayerIds.contains(soloID)
            } else {
                // Named teams are unlinked from the session on tap
                // (removeNamedTeam), so any that remain are wanted.
                wanted = true
            }
            if !wanted {
                context.delete(sessionTeam)
                session.sessionTeams.removeAll { $0.id == sessionTeam.id }
            }
        }

        let name = trimmedNewTeamName
        if canAddTeam {
            let team = Team(teamName: name)
            context.insert(team)
            let sessionTeam = PracticeSessionTeam(team: team)
            context.insert(sessionTeam)
            session.sessionTeams.append(sessionTeam)
            newTeamName = ""
        }

        let existingSoloPlayerIDs = session.sessionTeams.compactMap { Self.soloPlayerID(of: $0) }
        for playerID in selectedPlayerIds where !existingSoloPlayerIDs.contains(playerID) {
            guard let players = (try? context.fetch(FetchDescriptor<Player>()))?.first(where: { $0.id == playerID }) else { continue }
            let team = soloTeam(for: players, in: context)
            let sessionTeam = PracticeSessionTeam(team: team)
            context.insert(sessionTeam)
            session.sessionTeams.append(sessionTeam)
        }

        try? context.save()
    }

    /// The "Team of 1" for a player. Matched by name (a team named after the
    /// player) so records are reused instead of piling up, and never adds a
    /// player to a team that already has other members.
    private func soloTeam(for player: Player, in context: ModelContext) -> Team {
        let teams = (try? context.fetch(FetchDescriptor<Team>())) ?? []
        if let existing = teams.first(where: {
            $0.teamName == player.playerName && $0.players.count == 1 && $0.players.first?.id == player.id
        }) {
            return existing
        }
        if let reusable = teams.first(where: { $0.teamName == player.playerName && $0.players.isEmpty }) {
            reusable.players.append(player)
            return reusable
        }
        let team = Team(teamName: player.playerName, players: [player])
        context.insert(team)
        return team
    }

    /// The player ID when this session team is a provisioned "team of 1".
    static func soloPlayerID(of sessionTeam: PracticeSessionTeam) -> UUID? {
        guard let team = sessionTeam.team, team.players.count == 1 else { return nil }
        return team.players.first?.id
    }
}

extension TeamSetupViewModel: Identifiable {
    var id: UUID { session.id }
}

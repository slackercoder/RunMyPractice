import Foundation
import SwiftData
import Observation

/// MVVM form model for the participant setup sheet during a session (M4, v0.5.0).
///
/// During a practice, participants run the drills:
/// - **Named teams** — reusable roster `Team` records (e.g. "Team 1"),
///   selected with a checkmark.
/// - **Solo players** — roster `Player` records, each running as its own
///   "team of 1" (a values-only session row; no roster Team record is
///   provisioned — Technical Spec §4).
///
/// The draft (new team name, selected players, selected teams) is written to
/// the session only on Save, so Cancel cleanly discards it (`rollback`).
/// Enrollment upserts by source ID: re-enrolling an existing group re-freezes
/// its current labels instead of piling up duplicate rows. Score/check-off
/// records are created on first interaction in the execute view.
@Observable
final class TeamSetupViewModel {
    let session: PracticeSession

    var newTeamName = ""
    var selectedPlayerIds: Set<UUID> = []
    var selectedTeamIds: Set<UUID> = []

    init(session: PracticeSession, in context: ModelContext) {
        self.session = session
        refreshSelections()
    }

    /// Re-read the session's current participants so the sheet reflects state
    /// changed elsewhere (e.g. a player added in a nested sheet this visit).
    func refreshSelections() {
        selectedPlayerIds = Set(session.sessionTeams.compactMap(\.soloPlayerID))
        selectedTeamIds = Set(session.sessionTeams.compactMap(\.sourceTeamID))
    }

    /// Session rows for solo participants (a player running as a team of 1).
    var soloTeams: [PracticeSessionTeam] {
        session.sessionTeams.filter { $0.soloPlayerID != nil }
    }

    /// Session rows for named teams (including legacy/orphaned rows).
    var namedTeams: [PracticeSessionTeam] {
        session.sessionTeams.filter { $0.soloPlayerID == nil }
    }

    /// Named-team rows whose roster team no longer exists (or has no source at
    /// all — legacy rows from before v0.5.0): they can't be toggled back on,
    /// so the sheet shows them with a remove button.
    func orphanedTeams(teams: [Team]) -> [PracticeSessionTeam] {
        namedTeams.filter { row in
            row.sourceTeamID == nil || !teams.contains { $0.id == row.sourceTeamID }
        }
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

    func isTeamSelected(_ team: Team) -> Bool {
        selectedTeamIds.contains(team.id)
    }

    func toggleTeam(_ team: Team) {
        if selectedTeamIds.contains(team.id) {
            selectedTeamIds.remove(team.id)
        } else {
            selectedTeamIds.insert(team.id)
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
        enrollSolo(player, in: context)
        selectedPlayerIds.insert(player.id)
        try? context.save()
        return player
    }

    /// Deletes the roster player and its solo team-of-1 records, if any.
    /// Recorded runs are untouched — they keep their frozen copy of the label
    /// (see `Player.delete(in:)`).
    func deletePlayer(_ player: Player, in context: ModelContext) {
        player.delete(in: context)
        selectedPlayerIds.remove(player.id)
        // Also drop the player from the *current* session's participants:
        // the row can no longer be toggled (no roster entry), so a ghost
        // row would otherwise linger until discard. Recorded runs are
        // untouched — they keep their frozen copy of the label.
        if let row = session.sessionTeams.first(where: { $0.soloPlayerID == player.id }) {
            context.delete(row)
            session.sessionTeams.removeAll { $0.id == row.id }
        }
        try? context.save()
    }

    /// Deletes a participant row from the session immediately (scores cascade)
    /// and updates the draft. Cancel = `context.rollback()` restores it;
    /// Save persists the removal.
    func removeSessionTeam(_ sessionTeam: PracticeSessionTeam, in context: ModelContext) {
        if let sourceID = sessionTeam.sourceTeamID {
            selectedTeamIds.remove(sourceID)
        }
        context.delete(sessionTeam)
        session.sessionTeams.removeAll { $0.id == sessionTeam.id }
    }

    /// Creates or re-freezes the solo-participant row for a roster player.
    /// Solo participants are values-only rows — no roster `Team` record.
    private func enrollSolo(_ player: Player, in context: ModelContext) {
        if let existing = session.sessionTeams.first(where: { $0.soloPlayerID == player.id }) {
            existing.teamName = player.playerName
            existing.playerLabels = [player.playerName]
        } else {
            let row = PracticeSessionTeam(
                teamName: player.playerName,
                playerLabels: [player.playerName],
                soloPlayerID: player.id
            )
            context.insert(row)
            session.sessionTeams.append(row)
        }
    }

    /// Writes the draft to the session:
    /// - drops solo rows whose player was toggled off,
    /// - upserts solo rows for selected players (re-freezing current labels),
    /// - drops named rows that were toggled off or whose roster team is gone,
    /// - upserts named rows for selected roster teams,
    /// - enrolls a newly typed team name (matched to, or created in, the
    ///   reusable roster) — find-or-create by name keeps roster teams stable
    ///   across sessions instead of duplicating them.
    func save(in context: ModelContext) {
        guard isValid else { return }

        let allPlayers = (try? context.fetch(FetchDescriptor<Player>())) ?? []
        let allTeams = (try? context.fetch(FetchDescriptor<Team>())) ?? []

        for sessionTeam in session.sessionTeams where sessionTeam.soloPlayerID != nil {
            if let soloID = sessionTeam.soloPlayerID, !selectedPlayerIds.contains(soloID) {
                context.delete(sessionTeam)
                session.sessionTeams.removeAll { $0.id == sessionTeam.id }
            }
        }

        for player in allPlayers where selectedPlayerIds.contains(player.id) {
            enrollSolo(player, in: context)
        }

        for sessionTeam in session.sessionTeams where sessionTeam.soloPlayerID == nil {
            if let sourceID = sessionTeam.sourceTeamID {
                let stillWanted = selectedTeamIds.contains(sourceID)
                    && allTeams.contains { $0.id == sourceID }
                if !stillWanted {
                    context.delete(sessionTeam)
                    session.sessionTeams.removeAll { $0.id == sessionTeam.id }
                }
            }
            // Rows with no source (legacy) are kept as-is.
        }

        for team in allTeams where selectedTeamIds.contains(team.id) {
            if let existing = session.sessionTeams.first(where: { $0.sourceTeamID == team.id }) {
                existing.teamName = team.teamName
                existing.playerLabels = team.players.map(\.playerName)
            } else {
                let row = PracticeSessionTeam(
                    teamName: team.teamName,
                    playerLabels: team.players.map(\.playerName),
                    sourceTeamID: team.id
                )
                context.insert(row)
                session.sessionTeams.append(row)
            }
        }

        let name = trimmedNewTeamName
        if canAddTeam {
            let roster = allTeams.first { $0.teamName.caseInsensitiveCompare(name) == .orderedSame } ?? {
                let team = Team(teamName: name)
                context.insert(team)
                return team
            }()
            if !session.sessionTeams.contains(where: { $0.sourceTeamID == roster.id }) {
                let row = PracticeSessionTeam(
                    teamName: roster.teamName,
                    playerLabels: roster.players.map(\.playerName),
                    sourceTeamID: roster.id
                )
                context.insert(row)
                session.sessionTeams.append(row)
                selectedTeamIds.insert(roster.id)
            }
            newTeamName = ""
        }

        try? context.save()
    }
}

extension TeamSetupViewModel: Identifiable {
    var id: UUID { session.id }
}

import Foundation
import SwiftData

/// A participating group in a PracticeSession, snapshotted as values
/// (v0.5.0: self-contained run records).
///
/// The group is frozen into `teamName` + `playerLabels` when it is enrolled,
/// so editing or deleting roster teams/players after a run starts never
/// rewrites or destroys recorded runs. Team scores for the session hang off
/// this record.
///
/// `soloPlayerID` and `sourceTeamID` are plain values, deliberately **not**
/// relationships: they exist for provenance and upsert matching (re-freezing
/// current labels when the group is re-enrolled), and a deleted roster record
/// must never delete or break a run record. Solo participants no longer
/// provision roster "team of 1" records — the "team of 1" only exists in the
/// sync payload (M5 materializes it server-side).
@Model
final class PracticeSessionTeam {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var teamName: String
    var playerLabels: [String] = []
    /// Set when this row is a solo participant (the roster player it came from).
    var soloPlayerID: UUID?
    /// Set when this row came from a named roster team.
    var sourceTeamID: UUID?

    @Relationship(deleteRule: .cascade) var scores: [TeamScore] = []

    init(
        teamName: String,
        playerLabels: [String] = [],
        soloPlayerID: UUID? = nil,
        sourceTeamID: UUID? = nil
    ) {
        self.id = UUID()
        self.teamName = teamName
        self.playerLabels = playerLabels
        self.soloPlayerID = soloPlayerID
        self.sourceTeamID = sourceTeamID
    }
}

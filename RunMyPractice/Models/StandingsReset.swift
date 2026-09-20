import Foundation
import SwiftData

/// A one-way marker: "the standings clock started again at this time" (v0.7.0).
///
/// Player point totals are never stored — they are computed on the fly from
/// recorded runs (see `Player.totalPoints`). So a reset is not a deletion:
/// it appends one marker, and runs after the latest marker are what the
/// current standings count. Recorded runs stay intact, so what the standings
/// looked like before a reset (a finished monthly league, say) is still
/// reviewable in the runs list — the reset only stops those runs from
/// counting going forward.
///
/// This is the shape the "monthly points with a little prize" flow takes:
/// reset at the start of the month, run all month, review the leaderboard,
/// award the prize, reset again.
@Model
final class StandingsReset {
    @Attribute(.unique) var id: UUID
    var remoteId: Int?
    var date: Date
    /// Optional context, e.g. "June league — prizes awarded".
    var note: String?

    init(date: Date = Date(), note: String? = nil) {
        self.id = UUID()
        self.remoteId = nil
        self.date = date
        self.note = note
    }
}

import SwiftUI

/// Placeholder for the practice execution screen (M4).
///
/// The real screen records a PracticeSession against this template: team
/// assignment (individuals run as a background "team of 1"), per-drill
/// check-offs (DrillAcknowledgement), and per-team scores (TeamScore).
struct ExecutePracticeView: View {
    let practice: Practice

    var body: some View {
        ContentUnavailableView {
            Label("Execute Practice", systemImage: "play.circle")
        } description: {
            Text("Live execution of \"\(practice.title)\" arrives in milestone M4 — teams, check-offs, and scoring.")
        }
    }
}

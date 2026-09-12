import SwiftUI
import SwiftData

/// Sheet for adding a player/athlete to the roster (Functional Spec §5.5).
/// Thin wrapper so the Players tab keeps its own sheet type; the form itself
/// lives in PlayerFormView (shared with the execute screen's participant
/// sheet, where it also enrolls the player in the session).
struct CreatePlayerSheet: View {
    var body: some View {
        PlayerFormView()
    }
}

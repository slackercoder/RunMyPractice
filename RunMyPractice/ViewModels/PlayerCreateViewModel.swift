import Foundation
import SwiftData
import Observation

/// MVVM form model backing the "Add Player" sheet (M2).
///
/// Zero PII by design (Technical Spec §2): players are coach-assigned labels
/// (e.g. "Skip A", "Lead", a random code), never real names.
@Observable
final class PlayerCreateViewModel {
    var name: String = ""

    /// Matches the backend `PlayerName NVARCHAR(100)` column (Technical Spec §4.2).
    private let maxNameLength = 100

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedName.isEmpty && trimmedName.count <= maxNameLength
    }

    var validationMessage: String? {
        guard !isValid else { return nil }
        return trimmedName.isEmpty
            ? "Enter a label."
            : "Label must be \(maxNameLength) characters or fewer."
    }

    /// Creates the player in the local store (offline-first; sync is M5).
    @discardableResult
    func save(into context: ModelContext) -> Player? {
        guard isValid else { return nil }
        let player = Player(playerName: trimmedName)
        context.insert(player)
        try? context.save()
        return player
    }
}

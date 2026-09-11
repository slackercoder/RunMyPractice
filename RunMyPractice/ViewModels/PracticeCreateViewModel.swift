import Foundation
import SwiftData
import Observation

/// MVVM form model backing the "Create Practice" sheet (M2).
///
/// MVP create flow (Functional Spec §6): a practice starts with a title only;
/// activities and drills are added in the practice editor (M3).
@Observable
final class PracticeCreateViewModel {
    var title: String = ""

    /// Matches the backend `Title NVARCHAR(150)` column (Technical Spec §4.2).
    private let maxTitleLength = 150

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedTitle.isEmpty && trimmedTitle.count <= maxTitleLength
    }

    var validationMessage: String? {
        guard !isValid else { return nil }
        return trimmedTitle.isEmpty
            ? "Enter a title."
            : "Title must be \(maxTitleLength) characters or fewer."
    }

    /// Creates the practice in the local store (offline-first; sync is M5).
    @discardableResult
    func save(into context: ModelContext) -> Practice? {
        guard isValid else { return nil }
        let practice = Practice(title: trimmedTitle)
        context.insert(practice)
        try? context.save()
        return practice
    }
}

import Foundation
import SwiftData
import Observation

/// MVVM form model for the activity add/edit sheet (M3).
///
/// Drafts the field values and writes them back to the live `Activity` model
/// only on Save, so Cancel cleanly discards edits. For a just-added
/// activity, Cancel removes the placeholder from the practice.
@Observable
final class ActivityFormViewModel {
    let activity: Activity
    let parentPractice: Practice?
    let isCreating: Bool

    var title: String
    var description: String
    var minutes: Int

    init(activity: Activity, parentPractice: Practice? = nil, isCreating: Bool) {
        self.activity = activity
        self.parentPractice = parentPractice
        self.isCreating = isCreating
        self.title = activity.title
        self.description = activity.activityDescription ?? ""
        self.minutes = activity.timeAllottedInMinutes
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedTitle.isEmpty && trimmedTitle.count <= 150 && (1...600).contains(minutes)
    }

    var validationMessage: String? {
        if trimmedTitle.isEmpty { return "Enter a title." }
        if trimmedTitle.count > 150 { return "Title must be 150 characters or fewer." }
        if !(1...600).contains(minutes) { return "Time must be 1–600 minutes." }
        return nil
    }

    func save() {
        guard isValid else { return }
        activity.title = trimmedTitle
        let description = self.description.trimmingCharacters(in: .whitespacesAndNewlines)
        activity.activityDescription = description.isEmpty ? nil : description
        activity.timeAllottedInMinutes = minutes
    }

    func cancel(in context: ModelContext) {
        guard isCreating else { return }
        parentPractice?.activities.removeAll { $0.id == activity.id }
        context.delete(activity)
    }
}

extension ActivityFormViewModel: Identifiable {
    var id: UUID { activity.id }
}

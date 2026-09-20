import Foundation
import SwiftData
import Observation

/// MVVM form model for the drill add/edit sheet (M3).
///
/// Drafts the field values and writes them back to the live `Drill` model
/// only on Save, so Cancel cleanly discards edits. For a just-added drill,
/// Cancel removes the placeholder from its activity.
///
/// Numeric fields (max points / step) are kept as text in the form and parsed
/// on validation, which keeps entry simple on both iPhone and iPad.
@Observable
final class DrillFormViewModel {
    let drill: Drill
    let parentActivity: Activity?
    let isCreating: Bool

    var title: String
    var description: String
    var notes: String
    var isScored: Bool
    var maxPointsText: String
    var pointStepText: String
    var isCoachDrill: Bool

    init(drill: Drill, parentActivity: Activity? = nil, isCreating: Bool) {
        self.drill = drill
        self.parentActivity = parentActivity
        self.isCreating = isCreating
        self.title = drill.title
        self.description = drill.drillDescription ?? ""
        self.notes = drill.notes ?? ""
        self.isScored = drill.isScored
        self.maxPointsText = drill.maxPoints.map(String.init) ?? ""
        self.pointStepText = drill.pointStep.map(String.init) ?? ""
        self.isCoachDrill = drill.isCoachDrill
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var parsedMaxPoints: Int? {
        Int(maxPointsText.trimmingCharacters(in: .whitespaces))
    }

    var parsedPointStep: Int? {
        Int(pointStepText.trimmingCharacters(in: .whitespaces))
    }

    /// Live preview of the choice matrix (Technical Spec §5) while configuring.
    var scoreOptions: [Int] {
        guard isScored, let max = parsedMaxPoints, let step = parsedPointStep else { return [] }
        return generateScoreOptions(max: max, step: step)
    }

    var scoreOptionsPreview: String {
        guard !scoreOptions.isEmpty else { return "" }
        return scoreOptions.map(String.init).joined(separator: ", ")
    }

    var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        let titleValid = !trimmedTitle.isEmpty && trimmedTitle.count <= 150
        guard titleValid else { return false }
        guard trimmedNotes.count <= 2000 else { return false }
        guard isScored, let max = parsedMaxPoints, let step = parsedPointStep else { return true }
        return (1...100).contains(max) && (1...max).contains(step)
    }

    var validationMessage: String? {
        if trimmedTitle.isEmpty { return "Enter a title." }
        if trimmedTitle.count > 150 { return "Title must be 150 characters or fewer." }
        if trimmedNotes.count > 2000 { return "Notes must be 2000 characters or fewer." }
        guard isScored else { return nil }
        guard let max = parsedMaxPoints else { return "Enter max points (1–100)." }
        guard (1...100).contains(max) else { return "Max points must be 1–100." }
        guard let step = parsedPointStep else { return "Enter a point step (1–\(max))." }
        guard (1...max).contains(step) else { return "Step must be 1–\(max) (the max points)." }
        return nil
    }

    func save() {
        guard isValid else { return }
        drill.title = trimmedTitle
        let description = self.description.trimmingCharacters(in: .whitespacesAndNewlines)
        drill.drillDescription = description.isEmpty ? nil : description
        drill.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        drill.isScored = isScored
        if isScored, let max = parsedMaxPoints, let step = parsedPointStep {
            drill.maxPoints = max
            drill.pointStep = step
        } else {
            drill.maxPoints = nil
            drill.pointStep = nil
        }
        drill.isCoachDrill = isCoachDrill
    }

    func cancel(in context: ModelContext) {
        guard isCreating else { return }
        parentActivity?.drills.removeAll { $0.id == drill.id }
        context.delete(drill)
    }
}

extension DrillFormViewModel: Identifiable {
    var id: UUID { drill.id }
}

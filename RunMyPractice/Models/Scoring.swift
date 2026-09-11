import Foundation

/// Score option generation (Technical Spec §5): for a scored drill with a
/// max and a step, produce the choice matrix for UI pickers
/// (e.g. max 10, step 2 → [0, 2, 4, 6, 8, 10]).
func generateScoreOptions(max: Int, step: Int) -> [Int] {
    guard max > 0, step > 0 else { return [] }
    return Array(stride(from: 0, through: max, by: step))
}

extension Drill {
    /// Choice matrix for this drill's scoring configuration.
    /// Empty when the drill is unscored or its scoring config is incomplete.
    var scoreOptions: [Int] {
        guard isScored, let max = maxPoints, let step = pointStep else { return [] }
        return generateScoreOptions(max: max, step: step)
    }
}

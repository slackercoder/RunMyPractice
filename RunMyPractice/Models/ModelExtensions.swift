import Foundation
import SwiftData

/// Convenience accessors for ordered relationships. SwiftData does not
/// guarantee relationship array order, so views always sort explicitly.
extension Practice {
    /// Activities in intended run order.
    var orderedActivities: [Activity] {
        activities.sorted { $0.order < $1.order }
    }

    /// Sum of allotted time across all activities.
    var totalTimeInMinutes: Int {
        activities.reduce(0) { $0 + $1.timeAllottedInMinutes }
    }

    /// The in-progress execution of this practice, if one exists: the most
    /// recent session that has not been synced yet (synced sessions are
    /// finished runs). Session counts are small on-device, so fetch and filter
    /// rather than predicate on the optional practice relationship.
    func currentSession(in context: ModelContext) -> PracticeSession? {
        let sessions = (try? context.fetch(FetchDescriptor<PracticeSession>())) ?? []
        return sessions
            .filter { !$0.isSynced && $0.practice?.id == id }
            .max { $0.createDate < $1.createDate }
    }
}

extension Activity {
    /// Drills in intended run order.
    var orderedDrills: [Drill] {
        drills.sorted { $0.order < $1.order }
    }
}

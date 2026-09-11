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
}

extension Activity {
    /// Drills in intended run order.
    var orderedDrills: [Drill] {
        drills.sorted { $0.order < $1.order }
    }
}

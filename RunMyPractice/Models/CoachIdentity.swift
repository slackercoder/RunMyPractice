import Foundation
import SwiftData

/// This coach's local identity (M6b: client sync).
///
/// A single row generated on first launch. Its `coachId` (a fresh UUID) is
/// what the sync worker sends as the `X-Coach-Id` request header on every
/// sync call — the API scopes all synced records to it (Technical Spec §6).
///
/// Today it identifies *this device* (the MVP has no sign-in). When the
/// suite's sign-in lands, this row is the seam for swapping the
/// device-generated ID for the signed-in user's: replace the row on sign-in
/// and the next full-state sync re-establishes everything under the real
/// identity (upsert-by-UUID makes that a no-op except for ownership).
@Model
final class CoachIdentity {
    @Attribute(.unique) var id: UUID
    var coachId: UUID
    var createDate: Date

    init() {
        self.id = UUID()
        self.coachId = UUID()
        self.createDate = Date()
    }
}

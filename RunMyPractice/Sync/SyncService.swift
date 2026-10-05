import Foundation
import SwiftData
import Observation

/// The client sync worker (M6b): pushes this coach's complete dataset to the
/// Practice sync API (Technical Spec §6) and backfills the server-assigned
/// `remoteId`s.
///
/// **Full-state, one-way push.** Each sync sends *all* practices (with their
/// activities/drills), the *complete* drill library, and every *completed*
/// session not yet synced. The server upserts by client UUID (replace), so
/// no per-record change tracking or outbox queue is needed: the local store
/// is the source of truth, and the next sync converges the server to it.
/// (The drill-library endpoint also *deletes* server rows the client no
/// longer sends — practices/sessions don't, see the known gap below.)
///
/// **Triggers:** automatically when the app becomes active with unsynced
/// data (RootView watches `scenePhase`), and manually via the Sync button on
/// the Practices tab. `syncNow()` is re-entrancy guarded.
///
/// **Known gap (next milestone):** the server upserts practices/sessions
/// without deleting rows the client no longer sends, so a *deleted* practice
/// or recorded run still exists server-side. Deletion reconciliation needs a
/// future API change.
///
/// **Base URL** is `http://localhost:7217` — the API's local development
/// address (its `http` launch profile). Loopback is ATS-exempt, so the
/// simulator can reach an API running on the Mac with no Info.plist changes;
/// a physical device on the LAN would need an exception.
@MainActor
@Observable
final class SyncService {
    /// Coarse UI state; views derive their icon/label from it.
    enum Status: Equatable {
        case idle
        case syncing
        case synced(Date)
        case failed(String)
    }

    private(set) var status: Status = .idle

    /// The coach identity sent as `X-Coach-Id` on every sync request.
    let coachId: UUID

    private let modelContext: ModelContext
    private let baseURL: URL
    private let urlSession: URLSession
    private var inFlight = false

    init(modelContext: ModelContext, coachId: UUID, baseURL: URL? = nil) {
        self.modelContext = modelContext
        self.coachId = coachId
        self.baseURL = baseURL ?? URL(string: "http://localhost:7217")!
        self.urlSession = URLSession(configuration: .default)
    }

    // MARK: - UI-facing state

    var isSyncing: Bool {
        if case .syncing = status { return true }
        return false
    }

    /// Anything local the server has never received: a record whose
    /// `remoteId` is still nil (never synced) or a completed run not yet
    /// pushed. Drives the automatic foreground sync and the status line.
    var needsSync: Bool {
        countUnsynced(#Predicate<Practice> { $0.remoteId == nil }) > 0
            || countUnsynced(#Predicate<Activity> { $0.remoteId == nil }) > 0
            || countUnsynced(#Predicate<Drill> { $0.remoteId == nil }) > 0
            || countUnsynced(#Predicate<DrillLibrary> { $0.remoteId == nil }) > 0
            || pendingSessionCount > 0
    }

    /// Completed runs the server has not received yet.
    var pendingSessionCount: Int {
        var descriptor = FetchDescriptor<PracticeSession>(
            predicate: #Predicate<PracticeSession> { $0.isSynced == false && $0.completedDate != nil }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// One-line status for the Practices tab; nil = nothing to show.
    var statusDescription: String? {
        switch status {
        case .idle:
            guard needsSync else { return nil }
            let pending = pendingSessionCount
            return pending > 0
                ? "Not synced yet — \(pending) completed run\(pending == 1 ? "" : "s") waiting for the Practice API."
                : "Not synced yet — tap Sync when the Practice API is running."
        case .syncing:
            return "Syncing with the Practice API…"
        case .synced(let date):
            return "Synced \(date.formatted(date: .omitted, time: .shortened))"
        case .failed(let message):
            return message
        }
    }

    // MARK: - Sync

    /// Starts a full sync if one isn't already in flight.
    func syncNow() {
        guard !inFlight else { return }
        inFlight = true
        status = .syncing
        Task { await performSync() }
    }

    private func performSync() async {
        do {
            try await syncPractices()
            try await syncDrillLibraries()
            try await syncSessions()
            // One save per sync; if it fails the next sync simply re-pushes
            // the same full state (upsert-by-UUID makes this idempotent).
            try? modelContext.save()
            status = .synced(Date())
        } catch {
            status = .failed(
                (error as? SyncAPIError)?.errorDescription
                ?? error.localizedDescription
            )
        }
        inFlight = false
    }

    /// Practices batch: every template with its activities and drills.
    private func syncPractices() async throws {
        let practices = fetchAll(Practice.self)
        let data = try await post("/api/v1/sync/practices", body: practices.map(SyncPracticesRequest.init))
        let response = try decode(SyncPracticesResponse.self, from: data)
        for practice in practices {
            practice.remoteId = response.practices[practice.id] ?? practice.remoteId
            for activity in practice.activities {
                activity.remoteId = response.activities[activity.id] ?? activity.remoteId
                for drill in activity.drills {
                    drill.remoteId = response.drills[drill.id] ?? drill.remoteId
                }
            }
        }
    }

    /// Drill-library batch: the coach's complete standalone library. The
    /// server deletes rows the batch doesn't contain, so deleting library
    /// drills locally reconciles on the next sync.
    private func syncDrillLibraries() async throws {
        let libraries = fetchAll(DrillLibrary.self)
        let data = try await post("/api/v1/sync/drill-libraries", body: libraries.map(SyncDrillLibraryRequest.init))
        let response = try decode(SyncDrillLibrariesResponse.self, from: data)
        for library in libraries {
            library.remoteId = response.drillLibraries[library.id] ?? library.remoteId
        }
    }

    /// Sessions batch: every completed run not yet synced. Only these —
    /// in-progress sessions keep resuming locally and sync on completion.
    private func syncSessions() async throws {
        var descriptor = FetchDescriptor<PracticeSession>(
            predicate: #Predicate<PracticeSession> { $0.isSynced == false && $0.completedDate != nil }
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        guard !sessions.isEmpty else { return }

        let data = try await post("/api/v1/sync/sessions", body: sessions.map(SyncSessionRequest.init))
        let response = try decode(SyncSessionsResponse.self, from: data)
        for session in sessions {
            session.isSynced = true
            session.remoteId = response.sessions[session.id] ?? session.remoteId
            for activity in session.activities {
                activity.remoteId = response.activities[activity.id] ?? activity.remoteId
                for drill in activity.drills {
                    drill.remoteId = response.drills[drill.id] ?? drill.remoteId
                }
            }
            for team in session.sessionTeams {
                team.remoteId = response.sessionTeams[team.id] ?? team.remoteId
                for score in team.scores {
                    score.remoteId = response.scores[score.id] ?? score.remoteId
                }
            }
            for acknowledgement in session.acknowledgements {
                acknowledgement.remoteId = response.acknowledgements[acknowledgement.id] ?? acknowledgement.remoteId
            }
        }
    }

    // MARK: - Transport

    private enum SyncAPIError: LocalizedError {
        case cannotReach(String)
        case unauthorized
        case validationFailed(String?)
        case conflict
        case badResponse
        case server(statusCode: Int)

        var errorDescription: String? {
            switch self {
            case .cannotReach(let detail):
                return "Can't reach the Practice API — is it running? (\(detail))"
            case .unauthorized:
                return "The Practice API rejected this coach identity (401) — nothing was synced."
            case .validationFailed(let detail):
                let base = "The Practice API found a problem with some records and didn't sync them (400)."
                return detail.map { "\(base) \($0)" } ?? base
            case .conflict:
                return "The server has conflicting data for this coach (409) — try Sync again."
            case .badResponse:
                return "The Practice API returned a response the app couldn't read."
            case .server(let statusCode):
                return "The Practice API returned an error (HTTP \(statusCode))."
            }
        }
    }

    /// POSTs a JSON body to one sync endpoint with the `X-Coach-Id` header,
    /// mapping HTTP/transport failures to a coach-readable `SyncAPIError`.
    private func post(_ path: String, body: some Encodable) async throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(coachId.uuidString, forHTTPHeaderField: "X-Coach-Id")
        request.httpBody = try encoder.encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw SyncAPIError.cannotReach("\(baseURL.absoluteString): \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw SyncAPIError.badResponse
        }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            throw SyncAPIError.unauthorized
        case 400:
            throw SyncAPIError.validationFailed(Self.describeValidationError(data))
        case 409:
            throw SyncAPIError.conflict
        default:
            throw SyncAPIError.server(statusCode: http.statusCode)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw SyncAPIError.badResponse
        }
    }

    /// The API's 400 body is `{"errors": [{"propertyName": …, "errorMessages": […]}]}`;
    /// surface the first few so the coach can fix the offending record.
    private static func describeValidationError(_ data: Data) -> String? {
        struct Envelope: Decodable {
            struct Item: Decodable {
                var propertyName: String?
                var errorMessages: [String]?
            }
            var errors: [Item]?
        }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              let items = envelope.errors, !items.isEmpty else { return nil }
        let messages = items.prefix(3).compactMap { item -> String? in
            guard let message = (item.errorMessages ?? []).first else { return nil }
            if let name = item.propertyName, !name.isEmpty { return "\(name): \(message)" }
            return message
        }
        return messages.isEmpty ? nil : messages.joined(separator: " · ")
    }

    // MARK: - Queries

    private func fetchAll<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? modelContext.fetch(FetchDescriptor<T>())) ?? []
    }

    private func countUnsynced<T: PersistentModel>(_ predicate: Predicate<T>) -> Int {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
}

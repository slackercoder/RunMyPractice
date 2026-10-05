import SwiftUI
import SwiftData

/// Entry point for the RunMy Practice app.
///
/// Offline-first (Technical Spec §2): the local SwiftData container is the
/// single source of truth for the UI. There is no authentication in the MVP.
/// The sync worker (M6b, `Sync/`) pushes the coach's data to the Practice
/// sync API when it's reachable — created here, injected into the view
/// hierarchy as an environment object — while every record stays usable
/// on-device whether or not the API is up.
///
/// The container is built **explicitly** here (rather than with the
/// `.modelContainer(for:)` scene modifier) because the explicit path enables
/// store auto-migration: a store written by an older app version whose schema
/// no longer matches this one fails *loudly at launch*. Instead the app shows
/// a recovery screen ("start with fresh data" or try again). The no-argument scene
/// modifier used to open such a mismatched store silently — the app then ran
/// and rendered old data, but every save failed validation and was swallowed
/// by `try?` (the "practice not saving" bug, v0.5.1).
@main
struct RunMyPracticeApp: App {
    @State private var container: ModelContainer?
    @State private var storeProblem: String?
    @State private var syncService: SyncService?

    init() {
        let result = Self.makeContainer()
        _container = State(initialValue: result.container)
        _storeProblem = State(initialValue: result.problem)
        if let container = result.container {
            _syncService = State(initialValue: Self.makeSyncService(for: container))
        }
    }

    var body: some Scene {
        WindowGroup {
            rootContent
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if let container, let syncService {
            RootView()
                .modelContainer(container)
                .environment(syncService)
        } else if let storeProblem {
            StoreProblemView(problem: storeProblem) {
                resetStoreAndRetry()
            } onRetry: {
                retryOpen()
            }
        } else {
            ProgressView("Loading…")
        }
    }

    // MARK: - Container

    private static func makeContainer() -> (container: ModelContainer?, problem: String?) {
        do {
            let container = try ModelContainer(
                for: Practice.self, Activity.self, Drill.self, DrillLibrary.self,
                     Team.self, Player.self,
                     PracticeSession.self, PracticeSessionTeam.self,
                     TeamScore.self, DrillAcknowledgement.self,
                     StandingsReset.self, CoachIdentity.self,
                configurations: ModelConfiguration()
            )
            container.mainContext.autosaveEnabled = true
            return (container, nil)
        } catch {
            let storeURL = ModelConfiguration().url
            // Best-effort backup of the old store file while it still exists,
            // in case the user (or a future importer) wants it back.
            backupStoreIfNeeded(at: storeURL)
            return (nil, "The data saved on this device was written by a different version of RunMy Practice and can't be opened with this one.\n\nYou can start with fresh, empty data — the current data will be removed (a copy is kept inside the app's storage) — or quit.\n\n(\(error.localizedDescription))")
        }
    }

    /// Wipes the on-device store and rebuilds the container. Called from the
    /// recovery screen; if the rebuild fails for another reason (e.g. disk
    /// full) the screen reappears with the new error.
    private func resetStoreAndRetry() {
        do {
            let storeURL = ModelConfiguration().url
            Self.deleteStoreFiles(at: storeURL)
            let newContainer = try ModelContainer(
                for: Practice.self, Activity.self, Drill.self, DrillLibrary.self,
                     Team.self, Player.self,
                     PracticeSession.self, PracticeSessionTeam.self,
                     TeamScore.self, DrillAcknowledgement.self,
                     StandingsReset.self, CoachIdentity.self,
                configurations: ModelConfiguration()
            )
            newContainer.mainContext.autosaveEnabled = true
            container = newContainer
            syncService = Self.makeSyncService(for: newContainer)
            storeProblem = nil
        } catch {
            storeProblem = "Starting with fresh data didn't work — the store still couldn't be created.\n\n(\(error.localizedDescription))"
        }
    }

    /// Copies the store file (if present) into a `backups` folder next to it.
    private static func backupStoreIfNeeded(at storeURL: URL) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: storeURL.path) else { return }
        let backups = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("backups", isDirectory: true)
        try? fileManager.createDirectory(at: backups, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970)
        let destination = backups.appendingPathComponent("\(storeURL.lastPathComponent).backup-\(stamp)")
        try? fileManager.copyItem(at: storeURL, to: destination)
    }

    /// Removes the store file plus its SQLite sidecar files (-wal, -shm, …).
    private static func deleteStoreFiles(at storeURL: URL) {
        let fileManager = FileManager.default
        let directory = storeURL.deletingLastPathComponent()
        for suffix in ["", "-wal", "-shm", "-journal", "-tmp"] {
            let file = directory.appendingPathComponent(storeURL.lastPathComponent + suffix)
            try? fileManager.removeItem(at: file)
        }
    }

    /// Re-attempts opening the existing store (transient failures like a
    /// locked file resolve on retry; a schema mismatch will show the same
    /// problem again, and the user can then choose to start fresh).
    private func retryOpen() {
        let result = Self.makeContainer()
        container = result.container
        syncService = result.container.map(Self.makeSyncService)
        storeProblem = result.problem
    }

    /// Builds the sync worker for a fresh container: finds (or creates) the
    /// `CoachIdentity` row first, then wires the worker to the main context.
    private static func makeSyncService(for container: ModelContainer) -> SyncService {
        let coachId = ensureCoachIdentity(in: container.mainContext)
        return SyncService(modelContext: container.mainContext, coachId: coachId)
    }

    /// Finds the local `CoachIdentity` row, creating it on first launch.
    /// The row's `coachId` is the device-generated value sent as
    /// `X-Coach-Id` on every sync request; when sign-in lands this becomes
    /// the seam for the signed-in user's identity.
    private static func ensureCoachIdentity(in context: ModelContext) -> UUID {
        if let existing = (try? context.fetch(FetchDescriptor<CoachIdentity>()))?.first {
            return existing.coachId
        }
        let identity = CoachIdentity()
        context.insert(identity)
        try? context.save()
        return identity.coachId
    }
}

/// Full-screen recovery view shown when the on-device store can't be opened
/// (older app version with an incompatible schema, or a corrupted store).
struct StoreProblemView: View {
    let problem: String
    let onReset: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Can't Open Saved Data")
                .font(.title2.bold())

            Text(problem)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                onReset()
            } label: {
                Label("Start With Fresh Data", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

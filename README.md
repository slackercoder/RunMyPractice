# RunMy Practice

A mobile-first, offline-first app that helps coaches plan, run, and record practices — for any sport or game (curling, TCG, or anything else).

- **Plan** reusable practice templates: `Practice → Activities (segments) → Drills` (scored or check-off)
- **Run** a practice on the day: pair teams (individuals run as a values-only "team of 1" row — no extra roster records) with a practice, check off drills, and score them as you go
- **Sync** to the cloud automatically when the network returns (planned — the ice house has no Wi-Fi, so offline-first is the core)

## Status

| Milestone | Scope | Status |
|---|---|---|
| M1 | Project scaffold, SwiftData models, app shell | ✅ done (v0.1.0) |
| M2 | Home screen (list / search / create) + player roster | ✅ done (v0.2.0) |
| M3 | Practice editor (activities → drills, scoring config) | ✅ done (v0.3.0) |
| M4 | Execute practice (teams, check-offs, scores, session records) | ✅ done (v0.4.0) |
| UX polish | Full-height sheets, in-practice player/team setup, player deletion, visual drill scoring | ✅ done (v0.4.1) |
| Run records | Self-contained runs — each session snapshots the plan + group, so templates and rosters can be edited freely after runs | ✅ done (v0.5.0) |
| Data safety | Startup store validation + recovery screen; loud (alert) save/start failures | ✅ done (v0.5.1) |
| M5 | Run history & review — browse recorded runs, read-only run review, per-practice past runs; coach notes on drills | ✅ done (v0.6.0) |
| M6 | Sync worker + .NET Web API backend | ⬜ planned (was M5, parked) |

## Key decisions

- **No auth in the MVP** (decided 2026-09-10). The app runs entirely locally on the device; email/identity (RunMy identity server) arrives in a later phase.
- **Offline-first** (Technical Spec §2): the SwiftData container is the single source of truth for the UI; a background worker pushes to the .NET API when the network is available (M6).
- **Zero PII**: players are coach-assigned labels (nicknames, position codes).
- **Self-contained run records** (v0.5.0): a practice is a freely editable/shareable *template*; each run is an independent `PracticeSession` that snapshots the plan (activities + drills) and the participating group (team name + player labels, as values) at run start. Renaming or deleting a template or roster entry never rewrites or destroys recorded runs.
- **Loud data failures** (v0.5.1): the app opens the SwiftData store through an explicit container with auto-migration, so a store written by an older app version (incompatible schema) or a corrupted store fails at launch and shows a recovery screen — *start with fresh data* (the old store file is first backed up inside the app's storage) or *try again*. The editor's Done and the execute screen's start no longer swallow save errors: they alert and keep the user where they are. Without this, a schema-mismatched store opened silently and every save failed invisibly (the v0.5.0 "practice not saving" bug).
- **Privacy of synced data** (when identity lands, M6+): rosters (teams + players) sync as per-user private data — anchored to the signed-in user via `createdBy`. Practices are the shareable unit; session records stay private. See Technical Spec §7.
- **iOS 17+** (SwiftData floor), iPhone + iPad.

## Getting started

1. Open `RunMyPractice.xcodeproj` in Xcode (26 recommended).
2. Select the **RunMyPractice** scheme and a destination.
   - **Mac (works immediately):** choose the *My Mac* destination — the target is Mac Catalyst–enabled so you can run the app on macOS right away.
   - **iOS Simulator:** if no iOS platform/runtime is installed yet: Xcode → Settings → Components → *iOS* → install (or `xcodebuild -downloadPlatform iOS` from the terminal), then pick a simulator.
3. From the terminal, you can also build headlessly:
   ```bash
   # Catalyst (macOS) — no extra platform downloads needed:
   xcodebuild -project RunMyPractice.xcodeproj -scheme RunMyPractice \
     -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build
   ```
4. If the app shows a **"Can't Open Saved Data"** screen on launch, the data on the device was written by an older app version and the schema no longer matches. **Start With Fresh Data** clears it (a copy is kept in the app's `backups` folder) and the app continues with an empty store; **Try Again** re-attempts opening the existing store.

## Backlog / planned

- **M6 — cloud sync** (was M5; parked): background sync worker + .NET Web API backend (location TBD — in-repo vs separate repo, decision still open).
- Roster management screen for teams (teams are currently created only from the execute screen's participant sheet).

## Documentation

- [docs/RunMyPracticeFunctionalSpec.md](docs/RunMyPracticeFunctionalSpec.md) — functional spec
- [docs/RunMyPracticeTechnicalSpec.md](docs/RunMyPracticeTechnicalSpec.md) — technical spec (source of truth for architecture, models, and sync contract)

## Project layout

```
RunMyPractice/
├── docs/                                  # functional + technical specs
├── RunMyPractice.xcodeproj/               # project + shared scheme
└── RunMyPractice/
    ├── App/RunMyPracticeApp.swift         # SwiftUI entry point + ModelContainer
    ├── Models/                            # SwiftData models (tech spec §4.1) + view extensions
    ├── ViewModels/                        # @Observable form models (MVVM)
    ├── Views/                             # RootView + feature screens (Practices, Players)
    └── Assets.xcassets/
```

## Data model (abridged)

`Practice → Activities → Drills` (templates) and `PracticeSession → PracticeSessionTeam → TeamScore / DrillAcknowledgement` (execution; each session also carries its own snapshot of the plan's activities + drills). Every record carries a client-generated `id: UUID` plus an optional `remoteId: Int?` that the server backfills on first sync. See Technical Spec §4 for the full models and §6 for the sync payload contract.

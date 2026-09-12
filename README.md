# RunMy Practice

A mobile-first, offline-first app that helps coaches plan, run, and record practices — for any sport or game (curling, TCG, or anything else).

- **Plan** reusable practice templates: `Practice → Activities (segments) → Drills` (scored or check-off)
- **Run** a practice on the day: pair teams (individuals run as a background "team of 1") with a practice, check off drills, and score them as you go
- **Sync** to the cloud automatically when the network returns (planned — the ice house has no Wi-Fi, so offline-first is the core)

## Status

| Milestone | Scope | Status |
|---|---|---|
| M1 | Project scaffold, SwiftData models, app shell | ✅ done (v0.1.0) |
| M2 | Home screen (list / search / create) + player roster | ✅ done (v0.2.0) |
| M3 | Practice editor (activities → drills, scoring config) | ✅ done (v0.3.0) |
| M4 | Execute practice (teams, check-offs, scores, session records) | ✅ done (v0.4.0) |
| UX polish | Full-height sheets, in-practice player/team setup, player deletion, visual drill scoring | ✅ done (v0.4.1) |
| M5 | Sync worker + .NET Web API backend | ⬜ planned |

## Key decisions

- **No auth in the MVP** (decided 2026-09-10). The app runs entirely locally on the device; email/identity (RunMy identity server) arrives in a later phase.
- **Offline-first** (Technical Spec §2): the SwiftData container is the single source of truth for the UI; a background worker pushes to the .NET API when the network is available (M5).
- **Zero PII**: players are coach-assigned labels (nicknames, position codes).
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

## Backlog / planned

- **M5 — cloud sync**: background sync worker + .NET Web API backend (location TBD).
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

`Practice → Activities → Drills` (templates) and `PracticeSession → PracticeSessionTeam → TeamScore / DrillAcknowledgement` (execution). Every record carries a client-generated `id: UUID` plus an optional `remoteId: Int?` that the server backfills on first sync. See Technical Spec §4 for the full models and §6 for the sync payload contract.

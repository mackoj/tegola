# Handoff

The state of the work for whoever picks it up next: a new session, another agent, or the owner. Read this first, keep
it short and current.

**Updated:** 2026-11-01, after M4 finished on `m4-signals`.

**Resume here: two branches diverged from `main` overnight, and only one M4 can merge.** Nothing is merged; nothing
is uncommitted on either.

| | **PR #13** · `m4-signals` (Mac session) | **PR #12** (draft) · `claude/tegola-rearchitecture-jcq29f` (cloud session) |
|---|---|---|
| M4 | All of T4.1–T4.10: model, screens, notifications, seed, journey 5. `scripts/ci.sh` green (app, iOS snapshots, journeys) and `linux-core` green | Model half only (T4.1–T4.4), its own design: `ClockSignal`, `StatusReading`, `latestLog`, `dismissSignal(id, clock:, status:)` |
| M5 | — | Linux half, T5.1–T5.4: type guess, first-piece rules, testers, payoff |
| M6 | — | Linux half, T6.1–T6.7: import batches, the Importer API, the three importers, lookup queue, look-alikes |
| Decisions | D-56 to D-61 | D-56 to D-66: **the same numbers mean different things** |
| 200-object list | 13 signals, pinned in `SignalShelfTests` | 41 signals, `docs/testing/signals-200.md` |

## The owner's choice, and the recommended path

**Recommended: merge #13, then rebase #12's M5 and M6 onto it.** #13 is the complete, Mac-verified M4. #12's M4 is
the model half of the same tasks, built differently. Its M5 and M6 work is new and worth keeping. The rebase, for
whoever does it (a Mac session, since it touches `ValueText` and the seed's tests):
1. After #13 merges, branch from `main` and cherry-pick #12's commits from "M5 T5.1" on. Drop its six M4 commits
   (up to "M4: D-57, and the handoff for the Mac half").
2. **Renumber its decisions.** Its D-58 to D-66 become D-62 onwards. Its D-56 and D-57 are M4's and go with its M4
   commits. Update every citation in code comments and docs.
3. **Port it to #13's model:**
   - `ClockSignal` becomes `Signal`; `StatusReading` becomes `ObjectStatus.derive` with `ShelfSignals`;
     `latestLog` becomes `signalState`; `CareKind.batterySwapped` becomes a `serviced` log;
   - M5's `Clocks.firstSignalDate` reads `Signal.changesAt`;
   - M6's `ValueText` history cases join #13's (`signalDismissed` is already there).
4. **The 200-object lists disagree:** 41 signals against 13. #12's counts tapes from the year they were made, which
   #13 found floods the feed (D-58 here). Keep #13's.
5. Run `scripts/ci.sh` on the Mac, then open one PR for M5 and M6's model halves.

**The alternative** is to keep #12's M4 model and port #13's screens onto it. That's more work, and nothing about
#12's M4 has run on a Mac.

**One reading in #12 needs the owner either way:** its D-60 makes imported rows **unconfirmed**. That reverses D-38,
which the owner approved (D-54).

## Where things stand

- **Spec:** approved (`docs/PLAN.md`, answers in §10). Decisions on `m4-signals`: D-1 to D-61.
- **M1, M2, M3:** merged (PRs #5, #8, #9; `docs/milestones/M1.md` to `M3.md`).
- **M4 (signals), on `m4-signals`, PR #13:** `docs/milestones/M4.md`.
  - Clocks as signals with their reasons, always **Estimate**.
  - Status derivation, and the object's status slot with Dismiss and the remedies.
  - The signal feed from the Today strip, and status filters.
  - Clock notifications, offered once.
  - A 105-object seed with exactly one signal (journey 5).
  - A separate review's findings, all fixed.
- **tegola-server** (`mackoj/tegola-server`, D-41): its M1 is done. The app needs it from M6 on.

## What's next

1. **Owner:**
   - choose between #12 and #13 (above);
   - M4's readings: D-56's thresholds, D-58 (a tape's clock starts at its first backup), D-61 (the offer is a card);
   - #12's D-60 against D-38;
   - the exit tests with people: M3's 30 objects, and M4's 8 of 10 signals.
2. **The rebase** above, once #13 is merged.
3. **Then the Mac halves:**
   - M5: T5.5–T5.7, the first-piece screens;
   - M6: T6.8–T6.12, the camera, lookup and import screens.

   #12's `tasks/plan.md` and `tasks/todo.md` break them down.
4. **Later:** M7 (people), M8 (keeping, You: the `unfinished` toggle lives there), M9 (polish).

## Run it locally (Mac)

Needs Xcode 27.1 (Swift 6.4) with an iOS 26 or 27 simulator runtime. Node is needed for the API lint and the type
schema check.

```sh
scripts/test.sh                        # only what this branch changed
scripts/test.sh TegolaModel            # one package (macOS, swift test)
scripts/test.sh TegolaFeatures ObjectFeatureTests   # one test target
scripts/test.sh ios:TegolaFeatures     # a package on the iPhone simulator: snapshots run here
scripts/test.sh app                    # the app: TegolaTests + TegolaUITests (journeys)
scripts/ci.sh                          # the full gate → build/ci-summary.md (~10 minutes)
```

- **In the app:** the Shelf tab (board 01), with a seed shelf when launched with `--seed` in a debug build. Scan opens
  Add by hand, Find searches, and an object opens its seven slots. Activity and You are still placeholders (M7, M8).
- Never run bare `swift test`: swiftly's toolchain breaks snapshot testing. The scripts use `xcrun`.
- **If anything fails:** paste `build/ci-summary.md`, and the failing log it names, into a session.

## How the work is run

- **Branch:** one milestone branch from `main`, one commit per task, one PR per milestone. The owner merges.
- **Data model: clctn first** (D-54). The owner's earlier app, `mackoj/clctn` (cloned at `../clctn`), already
  solved most storage questions, and its database was fast and accurate. Before any new table, index, migration,
  query, search or import work, read its `docs/architecture/schema.sql`, `docs/adr/0006`–`0008`,
  `docs/engineering/pointfree.md` and `Tests/DatabaseTests/SchemaTests.swift`, and port what fits. A departure gets a
  D-entry. The known departures are D-39 (JSON `data` columns) and D-51 (pure Swift search; clctn's FTS5
  `objectSearch` is the way back).
- **Signals** (D-56 to D-61):
  - a clock is a pure function in `TegolaModel/Signal.swift`;
  - what it reads beyond the values is the object's `signalState`, kept by `apply`;
  - screens read `snapshot.signals(at:)` (`TegolaClients/Signals.swift`) so they agree, with the calendar from
    `\.calendar`;
  - a new clock needs a function, its inputs in `SignalState.inputs(of:)`, a remedy if it has one, and words in
    `ShelfViews/SignalText.swift`.
- **Sync:** storage follows sqlite-data's CloudKit `SyncEngine` rules: UUID keys, no `UNIQUE`, new columns nullable
  or `NOT NULL ON CONFLICT REPLACE DEFAULT`, no renames or drops. M4 added no table: `signalState` lives in the
  object's JSON, and settings are rows with fixed ids.
- **Architecture:**
  - Every shelf write is a `ShelfCommand` through `ShelfClient.perform`. `plan` checks the rules and the values (D-40,
    D-49). Settings are not commands: they go through `SettingsClient`.
  - Screens read with one SQLiteData `@Fetch` (`ShelfRequest`, `ObjectRequest`) and derive with the pure read models
    (`ShelfSummary`, `CollectionMeta`, `ObjectSlots`, `search`). The `@Fetch` snapshot is left out of state `==`
    (D-47).
  - Navigation: children send `.delegate(.open(Route))`, and only `AppFeature.push` pushes, onto Shelf's or Find's
    stack (`AppPath`). Each feature is its own target in `TegolaFeatures`. Shared value views are in `ShelfViews`,
    and test helpers in `FeatureTestSupport` (`seededShelf()`).
- **Strings:** use `Text("…", bundle: .module)` in packages; the guard test refuses un-bundled literals.
  - Don't put quotes inside an interpolation in a key; hoist the value into a local first.
  - After UI text changes, run `scripts/sync-strings.sh`, then add French for every new key and drop `stale` entries.
  - `scripts/xcstrings-check-language.py fr --summary …` and `scripts/test.sh TegolaTestSupport` check them.
- **Snapshots** (D-46): `assertScreenSnapshot` (`TegolaSnapshotTesting`, iOS only) writes to
  `docs/snapshots/<suite>/`.
  - Record new or changed ones with `SNAPSHOTS=record scripts/test.sh ios:<Package>`, then look at the PNGs.
  - A failing `xcodebuild` run can hang on this Mac, so record runs pass, and the script caps runs at 10 minutes when
    `timeout` exists.
- **Package.resolved:** resolving on a Mac drops OpenCombine (TCA needs it only on Linux) and rewrites the origin hash.
  If no pin was added, `git checkout` the file. If pins were added, keep them and put OpenCombine's back.
- **The Xcode project** is generated by `scripts/generate-xcodeproj.py`, with synchronised folders, so new files need
  no regeneration. Running the generator reorders the file without changing it; don't commit that churn.
- **Editing by script:** `swift-format` reflows lines, so a Python string replacement can miss silently. Assert that
  the old text is there, or grep that the change landed.
- **Type files:** `scripts/validate-types.sh` checks them against `schema/type.schema.json`. A new key goes in both the
  decoder and the schema.
- **Lookup contract:** `api/tegola-lookup.openapi.yaml`. Run `scripts/lint-api.sh`, then sync into tegola-server
  (D-41).
- **Cloud sessions** have no Xcode. Here's how to get Swift:
  - Fetch the `amd64` layers of `mirror.gcr.io/library/swift:6.4.2-noble` into `/opt/swiftroot` and `chroot` into it,
    with the repo, `/proc`, `/dev`, `resolv.conf`, the proxy CA and the proxy environment.
  - `scripts/test-linux.sh` then runs the pure packages and storage (install `libsqlite3-dev` first).
  - Feature, app and snapshot tests are Mac-only (D-32).
- **Reviews:** a separate review agent reads each milestone against the plan before its PR. Keep its scope narrow, and
  keep it off the simulator while a UI run is going.
- **Attribution:** commits and PRs carry no AI-assistant trailers or footers.

## Known issues

- TCA doesn't build on Linux with Swift 6.4, so feature tests run only on the Mac (D-32).
- `xcodebuild test` with a failing test sometimes never exits here (D-46).
- Search is pure Swift (D-51). If M9's 150 ms target on 2,000 objects fails, the FTS5 index comes back behind
  `search`.
- Money-kind fields aren't hidden with money off. No v1 type has one (M3 review, nit).

## Owner questions

Open: #12 or #13 for M4; M4's readings (D-56, D-58, D-61); #12's D-60, which reverses the approved D-38. The owner approved M2 and M3's (D-35, D-38, D-45, D-50, D-51; D-54).

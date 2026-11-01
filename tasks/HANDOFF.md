# Handoff

The state of the work for whoever picks it up next: a new session, another agent, or the owner. Read this first, keep
it short and current.

**Updated:** 2026-11-01, M4 done on `m4-signals` (PR into `main`). M5 is next.

## Where things stand

- **Spec:** approved (`docs/PLAN.md`, answers in §10). Decisions: `docs/DECISIONS.md`, D-1 to D-61.
- **M1, M2, M3:** merged (PRs #5, #8, #9; `docs/milestones/M1.md` to `M3.md`).
- **M4 (signals):** `docs/milestones/M4.md`. Clocks as signals with their reasons, always **Estimate**; status
  derivation; the object's status slot with Dismiss and the remedies; the signal feed from the Today strip; status
  filters; clock notifications offered once; a 105-object seed with exactly one signal (journey 5). The 200-object
  signal shelf is pinned (`SignalShelfTests`). A separate review's findings are all fixed.
- **tegola-server** (`mackoj/tegola-server`, D-41): its M1 is done. The app needs it from M6 on.

## What's next

1. **Owner:**
   - M3's exit test with people (30 objects in one sitting);
   - M4's: does a collector agree with 8 of 10 signals on a 200-object shelf?
   - the readings in M4's "For the owner": D-56's thresholds, D-58's backups, D-61's offer card.
2. **M5, launch types and first piece** (page 52 P3; exit test: 5 of 6 testers finish onboarding with one complete
   object). Start a branch `m5-first-piece` from `main`, and break M5 down in `tasks/plan.md` and `tasks/todo.md`
   first. Roughly:
   - Music, Video games, Board games and Thing as the launch data;
   - first-piece onboarding (46);
   - type inference via `ExtractionClient`.
3. **Later:** M6 (camera, lookup, import), M7 (people), M8 (keeping, You: the `unfinished` toggle lives there), M9
   (polish). `tasks/plan.md` has them.

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

M4's readings wait for the owner: D-56 (thresholds), D-58 (backups start a tape's clock), D-61 (the offer card). The owner approved M2 and M3's (D-35, D-38, D-45, D-50, D-51; D-54).

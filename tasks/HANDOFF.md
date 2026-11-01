# Handoff

The state of the work for whoever picks it up next: a new session, another agent, or the owner. Read this first, keep
it short and current.

**Updated:** 2026-11-01. M4's and M5's model halves are done (T4.1–T4.4, T5.1–T5.4); both screens halves wait for the Mac.

## Where things stand

- **Spec:** approved (`docs/PLAN.md`, answers in §10). Decisions: `docs/DECISIONS.md`, D-1 to D-59.
- **M1–M3:** merged (PRs #5, #8, #9; reports in `docs/milestones/`).
- **M4 (signals):** in progress on `claude/tegola-rearchitecture-jcq29f`, as a draft PR. The model half is done and
  verified on Linux (190 tests across the seven pure packages, zero warnings):
  - **T4.1 clock functions** (`Clocks`, `ClockSignal`). Care is kept on the object (`ShelfObject.latestLog`), and
    video games' disc rot is held pending (D-56).
  - **T4.2 status readings** (`StatusReading.derive` / `.all`, D-57). `TodayStrip` and `ShelfSummary` take
    `readings:`.
  - **T4.3 dismissals** (`ShelfCommand.dismissSignal`, `signalDismissed`).
  - **T4.4 the 200-object `SignalShelf`** and its golden list, `docs/testing/signals-200.md`: 41 signals.
- **M5 (launch types, first piece):** stacked on M4 on the same branch and PR. The model half is done and verified on
  Linux (214 tests, zero warnings):
  - **T5.1 type guess.** Type files have `recognise:` words; `Catalogue.guess(from:)` (D-58).
  - **T5.2 first-piece rules.** `ShelfCommand.firstPiece(draft, story:catalogue:)`, `notTheFirstPiece`; a type
    that hasn't shipped becomes a Thing with `awaitingType` via `ObjectDraft.recognised(as:)` (D-59).
  - **T5.3 testers.** `SettingKey.typeTesters` (`TypeTesters`) and `firstPieceSkipped`; `ShelfSnapshot` reads both,
    with `opensOnFirstPiece`. `Shelf.waiting(for:)`.
  - **T5.4 payoff.** `FirstPiecePayoff` and `Clocks.firstSignalDate`.
- **Waiting for the Mac:** T4.4b–T4.7 and T5.5–T5.7 touch the features, snapshots and the app.
- **tegola-server** (`mackoj/tegola-server`, D-41): its M1 is done. The app needs it from M6 on.

## What's next

1. **Owner:** M4's exit test. Read `docs/testing/signals-200.md`, mark the signals you agree with (8 of 10 passes),
   and say whether anything is missing. The cassette clock (every 2 years, counted from the release year when nothing's
   logged) is the one most likely to feel noisy; its parameter is in `ClockLibrary` (D-37).
2. **M4 on the Mac**, on the M4 branch (`tasks/plan.md`, M4):
   - **T4.5 status in the screens.**
     - `ShelfFeature` computes `StatusReading.all(shelf:catalogue:now:calendar:)` and passes `readings:` to
       `ShelfSummary`, so "N need attention" appears.
     - `ObjectView`'s status slot (D-48) shows the object's reading, with **ESTIMATE** when the reason is `.clock`, and
       a Dismiss action that sends `.dismissSignal(id, clock:, status:)` with the status shown.
     - Collection and Find filter by `status`.
     - Words: one String Catalog key per `StatusReading.Reason` and `ClockSignal.Reason` case, starting from
       `SignalListTests.phrase`, with French.
   - **T4.6 local notifications.** `NotificationsClient`. A clock's notifications are offered once, when the first
     clocked object arrives (PD-153), at most one per object per year (PD-017), from `ClockSignal.changesAt`. A loan
     reminder fires on the due date (PD-148).
   - **T4.7 journey 5 as a UI test.** Today → *1 needs attention* → a Game Boy cartridge whose battery is due → Log a
     battery swap (`.logEvent(id, kind: CareKind.batterySwapped, …)`) → the line is gone.
   - **T4.4b.** Grow `Seed.swift` toward 120 objects with clocks in every state, re-record the snapshots, and update
     the M3 counts knowingly.
   - **T4.8.** The M4 report, a separate review agent, and the carried skeleton candidates (`tasks/todo.md`).
3. **M5 on the Mac**, after M4's screens (`tasks/plan.md`, M5):
   - **T5.5 `ExtractionClient`** in `TegolaClients`: Foundation Models' guided generation describes a photo or a
     typed line as a name and words. `catalogue.guess(from:)` maps the words to a type. Unavailable without Apple
     Intelligence; `unimplemented` test value.
   - **T5.6 `FirstPieceFeature`**, PLAN F2's four screens. `AppFeature` opens on it when
     `snapshot.opensOnFirstPiece`; **Just look around first** sets `.firstPieceSkipped` to `"true"`. The write is
     `ShelfCommand.firstPiece(ObjectDraft.recognised(as: guess.type, …), story:, catalogue:)`. **Count me in** sets
     `.typeTesters` to `snapshot.typeTesters.adding(type).setting`. The payoff reads
     `FirstPiecePayoff(object:type:now:calendar:)`. `ShelfViews/ValueText.swift`'s history line reads
     "First piece · \(story)": give an empty story its own key.
   - **T5.7** the empty shelf's two offers; **T5.8** the first-piece UI test, `docs/UX-FINDINGS.md`, the report and
     the review.
4. **Later:** M6 (camera, lookup, import), M7 (people), M8 (keeping, You), M9 (polish).

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

The owner approved M2 and M3's readings (D-35, D-38, D-45, D-50, D-51; D-54). Open, for M5:

- **D-58:** the `recognise:` words in each type file are a first list. Add the words your testers use.
- **D-59:** the first piece's story is stored as the collector's words, not as a chip id, so it doesn't change
  language if they switch the app's language later. Say if it should.

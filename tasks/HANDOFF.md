# Handoff

The state of the work for whoever picks it up next: a new session, another agent, or the owner. Read this first, keep
it short and current.

**Updated:** 2026-11-01, after M5 finished on `m5-first-piece`.

**Resume here: M6's Mac half (T6.8–T6.12), after M5's PR merges.** M5 is done on `m5-first-piece`
(`docs/milestones/M5.md`). PR #15 (lookup contract 0.2.0, D-71) waits for tegola-server, which takes that work on.

## Where things stand

- **Spec:** approved (`docs/PLAN.md`, answers in §10). Decisions: D-1 to D-70.
- **M1 to M4:** merged (PRs #5, #8, #9, #13; `docs/milestones/M1.md` to `M4.md`).
- **M5 (launch types, first piece):** done. The Mac half: `ExtractionClient` (T5.5), `FirstPieceFeature`'s four
  screens and the app opening on it (T5.6), the empty shelf's **Scan your first object** (T5.7), journey 1 and the
  review (T5.8). D-72 records the readings. The model half (T5.1–T5.4):
  - **T5.1 type guess.** Type files have `recognise:` words; `Catalogue.guess(from:)` (D-62).
  - **T5.2 first-piece rules.** `ShelfCommand.firstPiece(draft, story:catalogue:)`, `notTheFirstPiece`. A type that
    hasn't shipped becomes a Thing with `awaitingType`, through `ObjectDraft.recognised(as:)` (D-63).
  - **T5.3 testers.** Settings `typeTesters` (`TypeTesters`) and `firstPieceSkipped`. `ShelfSnapshot` reads both and
    says `opensOnFirstPiece`. `Shelf.waiting(for:)` lists the Things waiting for a type.
  - **T5.4 payoff.** `FirstPiecePayoff`: the most urgent signal that needs attention, or else the soonest
    `Signal.changesAt` of a clock reading *good* ("Not yet. Soon.").
- **M6 (capture, lookup, import): the model half** is done (T6.1–T6.7):
  - **T6.1 import batches** (D-64). `ShelfCommand.importBatch(ImportBatch)` and `undoBatch(BatchID)`. Imported rows
    land **unconfirmed** (PD-047; D-38 allowed this). Undo, within 30 days, removes only the rows nobody touched
    (`ShelfObject.imported`) and soft-deletes them. New tables: `importBatches`, and `lookupQueue` (T6.6).
  - **T6.2 the Importer API** (D-65): `Importer`, `ImporterRegistry.v1`, `ImportPlan`, `CellExtracting`, and
    `NoteReader`, the rule-based cell reader.
  - **T6.3–T6.5 the three importers:** `TemplateImporter` (D-67), `SpreadsheetImporter` (grid and list, D-66) and
    `DiscogsCSVImporter` (D-68). The owner's `Jeux collection.csv`: 485 rows on 20 shelves, 12 to sort.
  - **T6.6** `LookupCandidate`, `EnrichmentProposal`, `LookupQueue` and `ShelfStore.perform(_:context:lookup:)`
    (D-69). **T6.7** `LookAlikes` and `MatchOutcome` (D-70).
- **Lookup contract 0.2.0** (D-71): `identifyObject` (`POST /types/{type}/identify`) takes words, OCR text, a
  barcode and a photo in any combination, and replaces `searchObjects`. tegola-server must sync the contract and move
  its search behind identify; its CI fails until it does.
- **tegola-server** (`mackoj/tegola-server`, D-41): its M1 is done. The app needs it from M6's T6.8 on.

## What's next

1. **Owner:**
   - M4's readings: D-56's thresholds, D-58 (a tape's clock starts at its first backup), D-61 (the offer is a card);
   - D-64: imported rows are unconfirmed, which takes up the option D-38 left open (keep or reverse);
   - D-72: the first piece's story chips, *What is it?*'s type chips, and the sync fallback;
   - the exit tests with people: M3's 30 objects, M4's 8 of 10 signals, M5's 5 of 6 testers (`docs/UX-FINDINGS.md`).
2. **M6 on the Mac** (`tasks/plan.md`, M6):
   - **T6.8 `LookupClient`** in `TegolaClients`:
     - it maps the generated `Candidate` to `LookupCandidate`, and the match buckets to `MatchOutcome`;
     - it needs `AppAttestMiddleware`, `RetryMiddleware` (`LookupQueue.Outcome.retryAfter`) and `ReachabilityClient`;
     - a worker drains `ShelfStore.lookupQueue()` and calls `recordLookup`;
     - add the `appattest-environment` entitlement (`tasks/todo.md`).
   - **T6.9 Capture:** VisionKit. A capture saves with `perform(.add(…, origin: .captured), context:, lookup:
     .barcode(…))`.
   - **T6.10 Import screens:**
     - `ImporterRegistry.v1.best(for:)`, then `plan(_:catalogue:extraction:)`. The sentence reads `collectionName`,
       `rows.count`, `types`, `shelves` and the `guessed` chips.
     - **Build my shelf** sends `.importBatch(plan.batch())` with source `.import`. Undo is `.undoBatch(id)`, and its
       summary reads `batchUndone`'s `kept`.
     - `ExtractionClient` implements `CellExtracting`; without Apple Intelligence, pass `NoteReader()`.
     - Matching sends rows to `POST /types/{type}/match`, 50 a call.
   - **T6.11** the review queue (`LookupCandidate.strength`, `EnrichmentProposal.apply(_:)`) and the match sheet
     (`LookAlikes.choices`). **T6.12** journey 2, the report, `REVIEW.md`, the review.
3. **Later:** M7 (people), M8 (keeping, You: the `unfinished` toggle lives there), M9 (polish).

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
  - The proxy port changes between sessions, so read `$HTTPS_PROXY` when you chroot. The proxy is HTTPS only: switch
    the rootfs's `ubuntu.sources` to `https://` and run apt with `-o APT::Sandbox::User=root -o
    Acquire::https::CAInfo=<the proxy CA>`. After a container restart, redo the bind mounts.
  - Plain `grep -r` over `Packages/` walks the `.build` folders: search `Packages/*/Sources` and `Packages/*/Tests`.
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

Open: M4's readings (D-56, D-58, D-61); D-64's unconfirmed imports; D-72. The owner approved M2 and M3's (D-35, D-38,
D-45, D-50, D-51; D-54).

# Implementation plan

Source of truth: `docs/PLAN.md` (spec) and `docs/DECISIONS.md`. This file breaks each milestone into tasks. A task is
one commit (or one PR) on the milestone's branch (PLAN §10, answer 7). A milestone ends with a report in `docs/milestones/M<n>.md` and a merge into `main`.

Each task lists what must be true when it's done (**Acceptance**) and how that is checked (**Verify**). "Linux" means
`scripts/test-linux.sh` in the cloud container or CI; "Mac" means `scripts/test.sh` / `scripts/ci.sh` with Xcode 27.1.

## Dependency graph

```
M1 foundation ──► M2 catalogue + model + storage ──► M3 core loop ──► M4 signals ──► M5 launch types + first piece
                                                                                         │
                                         M6 capture, lookup, import ◄────────────────────┘
                                                     │
                                         M7 people ──► M8 keeping + you ──► M9 polish
```

## M1 · foundation (PLAN §11)

Rule for M1 (from telaio's REVIEW): no empty placeholder targets. A package or target exists in M1 only if it has
something real to build and test. Feature targets arrive with their feature.

| Task | Acceptance | Verify |
|---|---|---|
| T1.1 Repo skeleton | `.gitignore`, `.swift-format`, `.periphery.yml` (telaio's, renamed); `scripts/` (`test.sh`, `ci.sh`, `test-linux.sh`, `lint-api.sh`, `secret-scan.sh`, `periphery.sh`, `sync-strings.sh`, `xcresult-summary.py`, `xcstrings-*.py`); `.github/workflows/ci.yml` with an automatic `linux-core` job and a manual `macos` job | `bash -n` on every script; `scripts/secret-scan.sh` passes; `scripts/lint-api.sh` passes |
| T1.2 Packages | Eight packages with telaio's manifest header (tools 6.2, three upcoming features), each with one real source file and one test: `TegolaCatalogue`, `TegolaModel`, `TegolaInterchange`, `TegolaLookupAPI`, `TegolaStorage`, `TegolaDesignSystem`, `TegolaFeatures`, `TegolaTestSupport` | Linux: the four pure packages build and test. Mac: all eight |
| T1.3 Lookup client | `TegolaLookupAPI` runs `swift-openapi-generator` as a build plugin over `api/tegola-lookup.openapi.yaml` (types + client); contract tests decode a recorded response for every operation | Linux: `swift test` in the package |
| T1.4 Design tokens and themes | `TegolaDesignTokens` (pure, no SwiftUI): the archive's palette, roles, `TegolaTheme.board`, typography specs, spacing, radii, borders, shadows; contrast tests over every role pair a component uses; derived text tokens where the archive fails AA (PLAN §10, answer 8). `TegolaDesignSystem` (SwiftUI): the theme in the environment, colour and font resolution, font registration, the three fonts with their OFL licences | Linux: tokens and contrast tests. Mac: font registration test |
| T1.5 Guard tests | Source-scanning tests: no hex or system colour outside the tokens; no `Date()`, `UUID()`, `Locale.current`, `Calendar.current`, `URLSession.shared` in sources; pure packages import no Apple UI framework; no `.public` log interpolation; no `print(` | Linux: `TegolaTestSupport` tests |
| T1.6 Fixtures | `TegolaTestSupport` carries `Jeux collection.csv`, recorded lookup responses, and the type files (the 17 from clctn plus `original-spec`'s newer ones) | Linux: a fixture-loading test |
| T1.7 App shell | `Tegola.xcodeproj` (hand-written, minimal: app, `TegolaTests`, `TegolaUITests`, local package refs, bundle id `fr.macko.tegola`, iOS 26.0); `AppFeature` root reducer with the five tabs and a `TestStore` smoke test; `TegolaClients` target | Mac: `scripts/test.sh app` (marked "needs a Mac run") |
| T1.8 Docs | `docs/DECISIONS.md` (D-1 to D-27 in telaio's format), `docs/GLOSSARY.md`, `docs/testing/ui-tests.md`, `tasks/HANDOFF.md`, `tasks/briefs/agent-brief.md`, `tasks/briefs/teststore-brief.md`, `docs/milestones/M1.md` | Read-through |

## M2 · catalogue + model + storage (page 52 P0)

Exit test: loading `video-game.yml` and `video-media.yml` gives the right field lists for all 13 subtypes.

Branch `m2-catalogue-model-storage`, one commit per task, one PR into `main`.

| Task | Acceptance | Verify |
|---|---|---|
| T2.1 Type schema v1 | `TypeManifest` reads every key PLAN §3.3 lists (gradient, consumable, allowMissing, lookup, searchable, related, placeLabel, signatures, subtypes with `label`/`presets`/`adds`, supersedes); keys only one legacy file uses stay accepted and unread. `schema/type.schema.json` (draft 2020-12) describes the same shape, and `scripts/validate-types.sh` checks every type file against it | Linux: `TegolaCatalogue`. `scripts/validate-types.sh` locally and in `linux-core` |
| T2.2 Type files move to subtypes | `video-game.yml` gets page 48's five subtypes (Saturn, N64, Neo Geo, Game Boy, PlayStation), `playStatus` (D-20), and loses `mediaRules` (D-18). `music.yml`'s `mediumRules` become vinyl, cd, cassette and other subtypes. Every `adds` entry has a label. The schema's `mediaRules`/`mediumRules` keys go | Linux: every file decodes and validates; schema check |
| T2.3 Resolver and the subtype rules | `resolve(type, subtype) -> EffectiveType`: parent fields, then the subtype's additions; presets fill, hide or narrow; parts and clocks from the subtype. Validation adds page 48's rules: an addition can't reuse a parent key, a narrowed choice is a subset of the parent's, a hidden or preset key exists, one level only, at most two signatures. **Exit test:** the 13 subtypes of `video-game.yml` and `video-media.yml` resolve to written-out field lists | Linux: `ResolverTests` |
| T2.4 Item level, clock library, signature kit | `item.yml` (title, acquired, price, place, story, Signed, Bundle of) decoded like a type file and merged by the resolver as hidden-until-set fields. `ClockLibrary`: the named clocks, each with its parameters (the functions arrive with signals in M4). `SignatureRenderer`: the closed set of renderers. Validation: clock names and renderers exist in the library | Linux |
| T2.5 Domain values | `ShelfObject`, `Work`, `ShelfCollection`, `Place`, `Person`, `Loan`, `ObjectDraft`, `FieldValue`, `ShelfEvent` (kind, payload, `at`, `seq`, source, batch), `ShelfCommand` (the PLAN §3.1 cases M3 needs first; the rest as cases that `plan` rejects as not yet supported) | Linux |
| T2.6 `plan` and `apply` | `plan(command, on: Shelf) throws(ShelfRuleViolation) -> [ShelfEvent]` and `apply(events, to: Shelf) -> Shelf`, pure. The rules in §3.1 step 1. Property tests over random command sequences for promises 1, 2, 3, 6, 7 and 8 (§3.4); 4 and 5 need the summary and screen state from M3 | Linux |
| T2.7 `TegolaStorage` | Package on sqlite-data: the first migration under `SyncEngine`'s rules (D-24), `ShelfClient.perform` appending events and updating the projection in one transaction, `rebuildProjection()`, and the replay test (a random command sequence's rebuilt tables equal the live ones). Check first whether sqlite-data and GRDB build on Linux | Mac: `scripts/test.sh TegolaStorage`; Linux if it builds there |
| T2.8 `ShelfClient`, seed shelf, docs | `TegolaClients` target with `ShelfClient`'s interface (D-31), live and test values. The seed shelf behind `--seed` (a few objects per v1 type, through `perform`). DECISIONS, GLOSSARY, HANDOFF, `docs/milestones/M2.md`. A separate review agent before the PR is marked ready | Mac: `scripts/ci.sh` |

## M3 · core loop (P1)

Exit test (page 52): someone adds 30 objects across Video games and Thing in one sitting without asking how. That's a
test with people, run by the owner. The automated stand-in is journey 1 (§4.4) as a UI test, plus a UI test that adds
30 objects by hand across the two types with no `--screen` shortcut.

Branch `m3-core-loop`, one commit per task, one PR into `main`. Screens follow the boards (`docs/design/BOARDS.md`);
where a board and the PD log disagree, the board sets the look and the log sets what's there (PLAN §4.0).

| Task | Acceptance | Verify |
|---|---|---|
| T3.1 Snapshot harness and the first components | Package tests can run on an iOS simulator (`scripts/test.sh ios:<Package>`), so snapshots use PLAN §2.6's iPhone 17 layout. `DesignSystemCatalog` with the components every M3 screen needs first: Card, Button (+ ButtonPair), Pill, Chip, StatusChip, ScreenHeader with a two-line `DisplayTitle` (the 0.96 line height), NavBar (large, back, modal), TabBar, `notYours()`, DashedButton, EmptyState. Snapshot per component and variant | Mac: `scripts/test.sh ios:TegolaDesignSystem` |
| T3.2 Read side | `Route` in `TegolaModel`. Pure read models over the projection: `ShelfSummary` (counts that never include wanted, borrowed or let go), `TodayStrip` (non-empty lines only: to tidy, need attention, overdue), a collection's meta line, `ObjectSlots` (the seven, in order). The money switch as a `settings` row read through a `SharedKey` (PD-161). Promises 4 and 5 as properties over random command sequences | Linux (model); Mac (settings) |
| T3.3 Navigation | `AppFeature` with the real tab bar (Shelf · Find · Scan · Activity · You), one stack per tab, the `Path` enum, `.delegate(.open(Route))` from children, and `--screen <name>` mapped to the same routes | Mac: `TegolaFeatures`, a UI flow per tab |
| T3.4 Shelf home (F3) | Header count (value only with money on), Today strip, stats card, collections as rows, the wishlist as a dashed collection, Places once two exist; the empty shelf (board 02) with **Type it** | Mac: TestStore, snapshots money on/off and empty |
| T3.5 Collection (F4) | Rows (photo or the type's flat tile), the mono meta line, sort, filters by place and status, rename, a mixed collection grouped by type | Mac |
| T3.6 Object (F4) | The seven slots in order for every v1 type; the ladder and set signatures; history as a timeline; actions Edit, Photo, Might let go (the rest arrive with their milestones) | Mac: `ObjectFeatureTests.sevenSlotsInOrderForEveryV1Type` |
| T3.7 Edit form (F5) | Form components (Text, Stepper, ChoiceChips, DateField, YesNo, Money, List, Event, FieldLabel, AutoBadge); one control per field kind over `EffectiveType.visibleFields`; **+ Add** for the item level; the Place path field; Cancel writes nothing, Save writes one `edited` event with the changed keys. `plan` checks values against their field (D-40) | Mac: `ObjectEditFeatureTests.cancelLeavesTheObjectUntouched`, `.saveAppendsOneHistoryEvent` |
| T3.8 Add by hand (F6, by hand) | Scan presents the add sheet with **Type it** (the camera is M6). Type, subtype and the form; **Add to** defaults to the last-used collection; the first object of a type creates its collection | Mac: `.firstObjectOfATypeCreatesItsCollection`, `.addToDefaultsToTheLastUsedCollection` |
| T3.9 Photos | `photos` table, `PhotoStoreClient` (files outside the database), `attachPhoto`; the hero shows the photo | Mac |
| T3.10 Find (F11) | `objects_fts` and `objectEntries` (one track on an LP is findable); stacking chips; each result says what matched; the Imperfect, Signed, Might let go and Duplicates saved views | Linux/Mac: `SearchTests.findsASingleTrackOnAnLP`; Mac: `FindFeatureTests` |
| T3.11 Places (F10) | The Places screen once two places exist, a place's objects, near-duplicate merge (`mergePlaces`) | Mac: `PlacesFeatureTests.screenAppearsOnlyOnceTwoPlacesExist` |
| T3.12 Journeys, seed, docs | Journey 1 and the 30-objects UI test; the seed grown toward 120 objects; DECISIONS, HANDOFF, `docs/milestones/M3.md` with the snapshots; a separate review agent | Mac: `scripts/ci.sh` |

## M4 · signals (P2)

Exit test (page 52): a 200-object shelf gives a signal list a collector agrees with on 8 of 10. That's a test with
people, run by the owner. The automated stand-ins are a generated 200-object shelf whose signal list is pinned against
a hand-checked expectation (T4.9), and journey 5, the weekly glance, as a UI test (T4.10).

Branch `m4-signals`, one commit per task, one PR into `main`. The ladder and set signatures shipped in M3 (T3.6), so
M4 is clocks, status, the signal feed, dismissals and notifications (F15; PLAN §3.3). A signal is a clock's reading
on one object: a status, its reason, and the date it next changes. It's always labelled **Estimate**.

Four places where the code and the spec disagree today. Each gets a D-entry with its task, for the owner to read:

- **Disc rot.** `video-game.yml` gives Saturn and PS1 `clock: discRot`, but PD-018 says v1 has no disc-rot clock.
  They become `discRot-pending` (D-37: named, shown nowhere until the evidence is in).
- **Code expiry.** F15 says `codeExpiry` applies to code cards, but no video-game field holds an expiry date. The type
  gains a `codeExpires` date field and names the clock; with no date set, there's no signal.
- **`playStatus`.** D-20's "started long ago, never finished" clock isn't in `ClockLibrary`. It joins the library as
  `unfinished`, off unless a setting turns it on.
- **The swatches.** Nothing says which state is which swatch. T4.3 proposes the mapping as a D-entry.

| Task | Acceptance | Verify |
|---|---|---|
| T4.1 Clock functions | A pure `Signal` (clock name, status, a structured reason, `changesAt`, always an estimate) and one function per library clock over an object's fields, its events and `now`, with its parameters from `ClockLibrary`. `saveBattery` uses the battery date or else the spine year, a 25–35-year lifespan, *watch* from 25 years, *act* past 35. A `serviced` event (Log a battery swap) resets it. `codeExpiry`, `drinkingWindow`, `serviceRisk` and `mediaRot` run as their definitions say; a pending clock gives no signal; `unfinished` runs only when its setting says so. The reason is data the view words ("Battery from 1994, usually lasts 25–35 years"). | Linux: `SaveBatteryClockTests.dueCartridgeShowsWatchWithItsReasonAndEstimate`, `.loggingASwapClearsIt`, one suite per clock |
| T4.2 Type files and the library | `discRot-pending` on Saturn and PS1 (PD-018); `codeExpires` and `clocks: [codeExpiry]` on `video-game.yml`; `unfinished` in the library, reading `playStatus` and the `playing` date; the schema and the validator know them. D-entries for the three. | Linux: `TegolaCatalogue`, `scripts/validate-types.sh`; the 13-subtype exit test still passes |
| T4.3 Status derivation | `ObjectStatus.derive` in `TegolaModel` (D-15): *gone* for let go; *act* for an overdue loan or an *act* signal; *watch* for a *watch* signal; *good* when a clock runs and reads well; *fine* otherwise. To tidy, needs details, lent, wanted and borrowed keep their M3 labels (D-48) and never count as needing attention, so the Today strip doesn't count them twice. A dismissed signal doesn't count. `ShelfSummary` and `TodayStrip` get real statuses. A D-entry records the mapping. Property test: wanted, borrowed and let go objects never need attention. | Linux: `StatusTests`, the promise properties |
| T4.4 Dismissals | `ShelfCommand.dismissSignal(ObjectID, clock:)` gives a `signalDismissed` event that records the clock, the status and the parameters in force (shape, never content; risk R2). `plan` refuses to dismiss a signal that isn't showing. A dismissal holds until the clock's reading gets worse (*watch* to *act*) or its input changes (a `serviced` event, an edited field). Before the projection and migration, read clctn's `schema.sql` and its ADRs 0006–0008 (D-54). | Linux: plan rules; Mac: `TegolaStorage` replay test |
| T4.5 The object's status slot | The slot shows the derived chip, the reason, **ESTIMATE**, and **Dismiss**. A `saveBattery` object gets **Log a battery swap** (a `serviced` event). The M3 states still show (D-48). Snapshots: a due cartridge, after a swap, after a dismissal. | Mac: `ObjectFeatureTests`, `scripts/test.sh ios:TegolaFeatures` |
| T4.6 The signal feed | The Today strip's *need attention* line opens the list of signals, most urgent first (`ObjectStatus` order), each with its reason, and each opens its object (a new `Route`, pushed by `AppFeature`). | Mac: `ShelfFeatureTests`, a new feature's tests, snapshots |
| T4.7 Status filters | Collection's filter by status (left out in T3.5) and Find's status chip, over the derived status. | Mac: `CollectionFeatureTests`, `FindFeatureTests` |
| T4.8 Notifications | `NotificationsClient` (live over `UNUserNotificationCenter`; the test value records calls). The offer comes once, in plain words, when the first clocked object arrives. With permission, each signal's `changesAt` is scheduled, and rescheduled or removed when the signal changes or is dismissed. The `unfinished` setting goes through `SettingsClient`; its toggle waits for You (M8). Loan-due reminders are M7's. | Mac: TestStore over the recorded calls |
| T4.9 Seed and the 200-object shelf | `Seed.swift` grows toward 120 objects, with due, swapped, dismissed and code-card objects. The M3 counts it changes are updated one by one. A generated 200-object shelf in `TegolaTestSupport` has its signal list pinned against a hand-checked expectation (the exit test's stand-in). | Linux: the 200-object test; Mac: the M3 suites |
| T4.10 Journey 5, docs, review | Journey 5 as a UI test: Today strip → *1 needs attention* → a Game Boy cartridge whose battery is due → Log a battery swap → the line is gone. DECISIONS, GLOSSARY (Signal), HANDOFF, `docs/milestones/M4.md` with the snapshots; a separate review agent before the PR is marked ready. | Mac: `scripts/ci.sh` |

## M5 · launch types + first piece (P3)

Exit test (page 52): 5 of 6 testers finish onboarding with one complete object and can say what the app will tell
them. That's a test with people, run by the owner; `docs/UX-FINDINGS.md` is where it's written down. The automated
stand-in is the first-piece journey as a UI test. The four launch types are data since M2 (D-23).

Branch: the session's branch, stacked on M4's model half (the payoff reads M4's clocks). T5.1 to T5.4 are pure model
and storage work, so they build and test on Linux. T5.5 to T5.8 touch the features, the on-device model and the app,
so they need the Mac.

| Task | Acceptance | Verify |
|---|---|---|
| T5.1 Type guess | Each type file names the words that recognise it, and its subtypes theirs (`recognise:`, decoder and schema). `Catalogue.guess(from:)` turns a description ("Omega Seamaster, 1968") into a type and subtype, says whether the type is enabled, and gives nothing on no words or a tie. Thing is never guessed. No word names two types (D-62) | Linux: `TypeGuessTests`; `scripts/validate-types.sh` |
| T5.2 First-piece rules | A first piece is the shelf's first object; its story is a chip and an optional line, kept as the collector's words, and it's the first history line, never `acquired` (PD-165). A piece of a type that hasn't shipped is saved as a Thing that remembers the type it's waiting for (46, 2B; D-63). It lands in the collection its type names (PD-137) | Linux: `PlanTests`, `FirstPieceTests`, storage replay |
| T5.3 Type testers | **Count me in** is a setting, the set of types the collector tests (PD-031). The pieces waiting for a type are a read model, so when the type ships they're offered the migration first (the migration is v1.x) | Linux: `ShelfStoreTests`, `ReadModelTests` |
| T5.4 The payoff | `FirstPiecePayoff`: the piece, the first thing its clocks say (any status, good included: "Not yet. Soon."), and its story. Page 46's two examples are tests | Linux: `FirstPieceTests` |
| T5.5 `ExtractionClient` | Foundation Models' guided generation describes a photo or a typed line as a name and words; `guess(from:)` maps them. Without Apple Intelligence it's unavailable, and the screen asks *What is it?*. `unimplemented` by default, recorded outputs in tests | Mac: TestStore with recorded outputs |
| T5.6 Onboarding | `FirstPieceFeature`'s four screens (PLAN F2): one question with the camera, **Type it**, **Library**, **Just look around first**; recognise, then *How did it come to you?*; type not shipped, with **Count me in** / **Not now**; the payoff, **One at a time** and **That's enough for today** (no sweep in v1). The app opens on it while the shelf is empty and it hasn't been skipped | Mac: TestStore, snapshots of every screen and state |
| T5.7 The empty shelf | **Scan your first object** and **Bring your list** (Add's import, from M6; hidden until then). No sample data (PD-102) | Mac: snapshot |
| T5.8 Journey and review | The first piece as a UI test (journey 1's first step). DECISIONS, the M5 report, HANDOFF, `docs/UX-FINDINGS.md` set up for the six testers, a separate review agent | Mac: `scripts/test.sh app`; read-through |

## M6 · capture, lookup, import (P4)

Exit test (page 52): `Jeux collection.csv` (485 games) imports in under 3 minutes, with under 5% of rows needing a
fix. The automated stand-in is `ImportIntegrationTests` over the real file (every cell kept, the counts, the payoff)
plus journey 2 (*Bring your list*) as a UI test; the 3 minutes are measured on a device with the on-device model.

Branch: the session's branch, stacked on M4 and M5. T6.1 to T6.7 are model, storage and parser work, so they build
and test on Linux. T6.8 to T6.12 touch the clients, the camera, the on-device model, the screens and the app, so they
need the Mac.

| Task | Acceptance | Verify |
|---|---|---|
| T6.1 Import batches | `ShelfCommand.importBatch(ImportBatch)`: one collection named after the file, every row `added` with origin `.imported` and the batch id, all **unconfirmed** (PD-042, PD-047; revises D-38's reading), never `acquired` (D-14). `undoBatch(BatchID)` within 30 days (PD-047) appends one `batchUndone` event that removes the rows nobody touched since and names the ones kept (D-12). `importBatches` table; a removed object's row is soft-deleted (`deletedAt`), never dropped | Linux: `PlanTests`, `ImportBatchTests`, storage replay |
| T6.2 The Importer API | `ImportInput` (bytes, file name, sheet tabs), `Recognition`, `Importer`, `ImporterRegistry` (the most certain wins; the collector can pick another), `ImportPlan` (collection name, typed rows, the one sentence, what was guessed, what was noticed) and `CellExtracting`, with a rule-based reader as the stand-in for the on-device model. Anything not read goes into the note, untouched | Linux: `ImporterRegistryTests` |
| T6.3 `TemplateImporter` | The `tegola.csv` template's columns, written down once (`TemplateFormat`) for Export (M8) to write. A file with its header imports with nothing guessed | Linux: `TemplateImporterTests` |
| T6.4 `SpreadsheetImporter` | Any other CSV, TSV or pasted text. A list with headers maps them (clctn's `ColumnMapping` aliases, English and French). A grid with a column per platform maps headers to subtypes, else to the platform field as written. The cell reader takes parts from "(cartouche + manuel)", condition notes from "boite endommagé", "/" as a bundle, "doublon" as a second copy, "dédicace" as signed, "(digital)" apart. **Jeux:** 485 rows, every cell kept, under 5% flagged | Linux: `ImportIntegrationTests` |
| T6.5 `DiscogsCSVImporter` | Discogs' collection export (Catalog#, Artist, Title, Label, Format, Released, release_id, the two conditions, notes) into Music with the medium as subtype; the grades map to the type's scale or stay in the note | Linux: `DiscogsCSVImporterTests` |
| T6.6 Lookup queue and enrichment | `LookupQueue` (pure): enqueue with the object, oldest first, exponential backoff, five attempts then "needs details", `Retry-After` honoured. `LookupCandidate` (reasons, confidence, sources, strength); `EnrichmentProposal` is what `applyLookup` would fill, which is only empty fields (PD-045); the `lookupQueue` table, filled in the add's own transaction | Linux: `LookupQueueTests`, `EnrichmentTests` |
| T6.7 Matches and look-alikes | `LookAlikes` (pure): "you already own this", another print, related objects from the manifest's `related` keys; the three choices; never a merge (PD-151). The exceptions queue as a read model over an import's unmatched and ambiguous rows | Linux: `LookAlikeTests` |
| T6.8 `LookupClient` | `TegolaClients` wraps the generated client: `AppAttestMiddleware` (`swift-keychain`, debug token on the simulator), `RetryMiddleware`, `ReachabilityClient`, the queue's worker effect; the `appattest-environment` entitlement | Mac: TestStore with recorded responses |
| T6.9 Capture | The Scan tab's camera (VisionKit barcode and text), the tray, Add to, the shot saved before any network | Mac: TestStore; snapshots |
| T6.10 Import screens | `ImportFeature`: Add's **Import a list**, the share sheet, the one sentence with rename, **Build my shelf**, **Something's off** (the column mapper), the payoff, undo. `ExtractionClient`'s cell extraction (Foundation Models, 20–30 cells a call) behind `CellExtracting`; the rule-based reader without Apple Intelligence | Mac: TestStore with recorded outputs; snapshots |
| T6.11 Review queue and matches | F7 and F8's screens: grouped rows with why, **Confirm**, **Fill in**, **Confirm all** for strong matches only; the match sheet's three choices; enrichment asks first | Mac: `ReviewQueueFeatureTests`, `MatchFeatureTests` |
| T6.12 Journey 2, docs, review | *Bring your list* as a UI test (`--import-fixture`), the empty shelf's **Bring your list** (T5.7), DECISIONS, the M6 report, HANDOFF, `REVIEW.md` (skeleton candidate), a separate review agent | Mac: `scripts/test.sh app`; read-through |

## M7 · people · M8 · keeping + you · M9 · polish

Lending, Activity, share cards; wishlist, let go, archive, saved views, settings, export, inventory document,
nudges, analytics, debug screen; French, accessibility, journeys, performance. Broken down when M6 merges.

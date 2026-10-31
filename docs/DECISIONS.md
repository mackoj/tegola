# Tegola: decisions

**What this is.** How Tegola reads its specification where it is unclear, contradicts itself, or meets reality. The
spec is `docs/PLAN.md`; product decisions are clctn's `PD-###` log and the owner's answers (PLAN §10). A question that
comes up during a task gets a new number here, and the task carries on with that reading (PLAN §9). Numbers are never
reused; a replaced decision stays, marked **superseded by D-n**.

**Format.** Each entry names the question and gives the decision, with its source.

---

### D-1 · Which archive is the original spec

**Decision.** `original-spec/` in this repo. Its September pages match `clctn/design/` byte for byte; the October pages are reconciled as §0 row 15 says

### D-2 · Loans without a backend

**Decision.** Every loan is closed by the collector; the borrower can't confirm, and the screen says so (PD-160)

### D-3 · History of a loan doesn't say to whom (journey 3 finding)

**Decision.** `lent` and `returned` events carry the person's id and name at the time

### D-4 · Camera throws you out after every shot (journey 1 fault 3)

**Decision.** The camera stays open, and new objects collect in a tray

### D-5 · No place field in the edit form (journey 1 fault 2)

**Decision.** The edit form has a Place field (F5)

### D-6 · Nudge with no link

**Decision.** The share sheet with a friendly line and the object card

### D-7 · Value fields with money off

**Decision.** Paid is recorded and editable, never totalled; value and price cap are hidden (stories 161, 165)

### D-8 · Runs and sets (stories 195–206)

**Decision.** v1 shows series and "also exists on" from owned objects only, through the work layer (47); it never invents a total (#23). Declaring a run, its gaps and "finished" are not in v1

### D-9 · Analytics destination with no backend

**Decision.** Local only, visible in the debug screen; no network

### D-10 · Dark mode

**Decision.** Not in v1, but the design system is themeable so a dark theme is a new `TegolaTheme` value (Q5, D-26); v1's Board theme keeps the dark "stage" surfaces where the boards have them

### D-11 · Token values disagree

**Decision.** The archive's handoff table wins over both implementations: muted is `#6E6458` (clctn has `#5A5045`); teal `#12A594` is a type tint and green `#0E6E5E` means money (the-collection calls `#0E6E5E` "teal"). Six manifests use gradient keys the palette lacks (claret, verdigris, phosphor, oxide, indigo, plum); they get tokens, taken from the archive's type pages.

### D-12 · Import undo after the collector has changed things

**Decision.** Undo removes the batch's objects that nobody touched since the import. Objects that were edited, photographed, lent or placed are kept, and the summary says "3 kept because you changed them". clctn hard-deleted them, which destroys work (PD-090's spirit).

### D-13 · "It arrived" on a wanted object

**Decision.** The object moves from the wishlist to its type's collection (created if needed), and history records `owned`. clctn left it in the wishlist.

### D-14 · Imported rows and `acquired`

**Decision.** An import writes `added` only. It writes `acquired` only from a column the mapping assigns to it, and dates the event, not the field, as the collector's own fact (PD-165).

### D-15 · Status mapping (five swatches)

**Decision.** It is derived in `TegolaModel` from 42_One Roof's rules, not in views. `unconfirmed` reads "To tidy" (clctn showed "Out"), `lent` reads "Out", overdue and needs details read "Needs you".

### D-16 · October pages vs the PD log

**Decision.** The October refinements are adopted where they don't contradict a confirmed decision; where they do (backend, accounts and subscription, marketplace payments), the PD log holds in v1 until Q9 is answered (§0 row 15)

### D-17 · Event log or mutable rows

**Decision.** Both: the log is the truth, and the rows are a projection written in the same transaction and rebuildable from it (§3.1). clctn's ADR-0006/0007 rows and JSON fields stay as the projection's shape

### D-18 · Video games' `mediaRules` (43) vs subtypes (48)

**Decision.** Subtypes keyed on platform replace `mediaRules`; music's per-format rules become format subtypes (48 Q1, Q2 leanings). `video-game.yml` gains the 5 subtypes page 48 draws

### D-19 · Consoles

**Decision.** Not a subtype of Video games; hardware is its own type, linked to the games it runs (47 D1, 48 Q4). Not in v1

### D-20 · `playStatus` (47 ask 05)

**Decision.** `video-game.yml` gains `playStatus` (not started / playing / finished / abandoned), replacing `playLog`'s finished flag. Its "started long ago, never finished" clock is opt-in

### D-21 · Import grouping

**Decision.** One collection per file, platforms as shelves inside it from the subtype, sheet tabs as statuses (49 §06). If a video-game collection exists, the confirm sentence offers to add to it instead; that's a choice the collector makes, so PD-151's never-merge holds

### D-22 · Digital games in an import

**Decision.** Kept, as `media: digital`, in the Digital view (49), and never counted as physical objects in stats, since the catalogue is physical (PD-024)

### D-23 · v1 types

**Decision.** Music, Video games, Board games and Thing (owner, 2026-10-31), superseding PD-164's Books and Wine. Video games carry v1's clock (`saveBattery`)

### D-24 · ULID (page 52) vs UUID

**Decision.** UUID primary keys, as SQLiteData's `SyncEngine` needs for the iCloud sync planned after v1 (Q4); the event log is ordered by `at`, then a per-device `seq`

### D-25 · Q3 and Q9 together

**Decision.** One backend in v1, tegola-server, for lookups and import matching only, under the OpenAPI contract and App Attest. No accounts, sync service, subscription or CDN

### D-26 · Theming

**Decision.** Roles, not colours, in every view; `TegolaTheme` maps roles to values; v1 ships the Board theme only (Q5)

### D-27 · Import sources

**Decision.** An `Importer` protocol and a registry; v1 ships the template, Discogs CSV and spreadsheet importers (Q11)

### D-28 · Which copy of a type file ships

**Decision.** clctn's `Sources/TypeCatalogue/Types/*.yml` (17 files) plus `original-spec/video-media.yml`. Where both clctn and `original-spec/` have a file, clctn's is the later one: it adds `hobby` and fixes YAML the design copies can't parse (`cart -> mediaCondition` is not a mapping). PLAN §3.3 said the reverse; this corrects it. `CatalogueTests.everyManifestDecodesAndValidates` reads all 18.

### D-29 · A choice field with no options of its own

**Decision.** Valid only when every subtype presets its options (page 48: a subtype may narrow a choice); otherwise nobody could pick a value, so it's a validation problem. Video Media's `packaging` is the case that found the rule.

### D-30 · Field kinds the type files spell differently

**Decision.** `int` reads as number and `bool` as yes/no, declared in one alias table (`FieldKind.aliases`). Any other unknown kind is a decoding error, not a silent fallback to text as in clctn, which hid typos.

### D-31 · Packages that would be empty in M1

**Decision.** None is created (telaio's REVIEW §2 found five empty feature targets inflating its counts). `TegolaStorage` arrives with M2, and each feature target with its milestone. M1's `TegolaFeatures` has `AppFeature` only.

### D-32 · Where the pure core is tested

**Decision.** On Linux with Swift 6.4.2, in CI (`linux-core`, every push) and in cloud sessions, which have no Xcode: `TegolaCatalogue`, `TegolaModel`, `TegolaInterchange`, `TegolaLookupAPI`, `TegolaTestSupport` and `TegolaDesignSystem`'s `TegolaDesignTokens`. TCA doesn't build on Linux (its dependency swift-navigation fails there with Swift 6.4), so `TegolaFeatures` and the app are verified on the Mac only, and say so in each report.

### D-33 · The lookup contract's search request

**Decision.** `SearchRequest` needs one of `title`, `text` or `catalogueNumber`. That rule is in the description, and the server answers `400`, rather than as a schema `anyOf` of required lists, which swift-openapi-generator turns into three empty payload types (it warns, and the client gets worse).

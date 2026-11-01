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

**Decision.** `int` reads as number, `bool` as yes/no and `enum` (page 48's spelling) as choice, declared in one alias table (`FieldKind.aliases`). Any other unknown kind is a decoding error, not a silent fallback to text as in clctn, which hid typos.

### D-31 · Packages that would be empty in M1

**Decision.** None is created (telaio's REVIEW §2 found five empty feature targets inflating its counts). `TegolaStorage` arrives with M2, and each feature target with its milestone. M1's `TegolaFeatures` has `AppFeature` only; `TegolaClients` (PLAN §2.4) arrives with its first client (`ShelfClient`'s interface, M2).

### D-32 · Where the pure core is tested

**Decision.** On Linux with Swift 6.4.2, in CI (`linux-core`, every push) and in cloud sessions, which have no Xcode: `TegolaCatalogue`, `TegolaModel`, `TegolaStorage` (from M2, with `libsqlite3-dev`), `TegolaInterchange`, `TegolaLookupAPI`, `TegolaTestSupport` and `TegolaDesignSystem`'s `TegolaDesignTokens`. TCA doesn't build on Linux (its dependency swift-navigation fails there with Swift 6.4), so `TegolaFeatures` and the app are verified on the Mac only, and say so in each report.

### D-33 · The lookup contract's search request

**Decision.** `SearchRequest` needs one of `title`, `text` or `catalogueNumber`. That rule is in the description, and the server answers `400`, rather than as a schema `anyOf` of required lists, which swift-openapi-generator turns into three empty payload types (it warns, and the client gets worse).

### D-34 · What a subtype's preset means

**Decision.** Page 48 writes presets three ways, and each has one meaning. The word `hidden` hides the field. One value fills the field and hides it (Saturn → media: disc, "the media picker is hidden"). A list narrows a choice to those options (DVD's region codes). `parts`, `clock` and `lookup` aren't parent fields: they are the subtype's set-signature parts, its clocks from the library (`none` for none) and the identifiers its capture reads. Every added field has a label, like a type's own fields, so `video-media.yml`'s additions got theirs.


### D-35 · What the medium tables become

**Decision.** Video games' `mediaRules`, music's `mediumRules` and vehicles' `kindRules` become subtypes, and the tables are gone from the schema (D-18).
- **Video games:** page 48's five platforms (Saturn, N64, Neo Geo, Game Boy, PlayStation). Each fills in the platform and media, and names its parts, lookup and clock. A platform without a subtype works with the parent's fields, and its set signature counts the parent's two generic slots (manual, insert). The floppy, card and code rows of 43 have no platform subtype yet, so `mediaRot` and `codeExpiry` aren't used by any video game until one is written. PlayStation's reprint label is `printLabel`, so that no field is called `label`.
- **Music:** vinyl, CD, cassette and other. Each narrows the formats and adds its own fields. The matrix code is needed by vinyl and CD, so it stays on the parent (48, Q3).
- **Dropped:** the per-medium marks and the per-medium names for the packaging and service fields (Sleeve, Case, J-card; Last cleaned, Last respooled). A subtype can't rename a parent field (48), so the parent's labels stand. If collectors miss them, that's a schema change for the owner.

### D-36 · A subtype's replacement field, and sets with no slots

**Decision.** CED's caddy `replaces` the case (`video-media.yml`), which sits against page 48's "can't remove or rename a parent field". The reading: the addition takes the parent field's place in the form and on the ladder, and the parent field is hidden for that subtype, keeping its own key and any value. Nothing is renamed, so a CED that later changes subtype loses nothing. The replacement must be of the same kind. A set field whose slots come from the subtype (`slotsFrom: subtype`) needs slots of its own unless every subtype names parts, the same rule D-29 makes for choices. Video Media's DVD, HD DVD, Blu-ray and 4K UHD name no parts on page 51, so its `inserts` has four generic slots (case, disc, booklet, insert).

### D-37 · The item level, and the clock and signature libraries

**Decision.**
- **Item level.** `item.yml` (in `TegolaCatalogue/Item`, not with the type files) holds the fields that mean the same on every type and are hidden until set (48, section 00):
  - `signed`: a list of by, dedication, date and proof, because a band signs once each;
  - `contains` (Bundle of): the works inside the object;
  - `bundleSealed`.
  
  Title, acquired, price, place and story are the item level too, but they're the spine and the slots. No type field may take an item-level key, so music's and books' yes/no `signed` go. Artwork's `signed` records where the signature sits (recto, verso, stamped), so it's renamed `signaturePosition` rather than dropped. Action figures' and Lego's `sealed` means "unopened", so the item level's is `bundleSealed`.
- **Clocks.** The library is `saveBattery`, `discRot`, `mediaRot`, `codeExpiry`, `drinkingWindow` and `serviceRisk`, each with what it reads and its default parameters. The functions arrive with signals in M4. A type names clocks at the top level (`clocks:`) or per subtype, and the subtype's come after the type's. `-pending` (page 51's `discRot-pending`) is the same clock held back until there's evidence, not a clock of its own. Wine names `drinkingWindow`.
- **Signatures.** The kit is ladder, set, gauge, panel, map and case (48's "existing case signature" for bundles).

### D-38 · How `plan` reads the rules it isn't told

**Decision.**
- **Origin and source.** An origin must come from its source: typed and first piece from the collector, a capture from the camera, an import from the importer. Without that, a lookup could add an object "typed" and confirmed (review of M2, finding 6).
- **Identity on add.** An object typed by the collector, their first piece and an imported row are confirmed. The import is the collector's own list, mapped by them. A capture is unconfirmed, or needs details when nothing was identified, until the collector confirms it (PD-042). M6 can make imported rows unconfirmed if the review queue needs them to be.
- **Titles.** Every object needs a title, except a capture with nothing identified. Confirming one still needs a title.
- **A lookup** fills a key only when it's empty, or when the lookup filled it before and the collector hasn't touched it since. Its values are AUTO until then (PD-042, PD-045). Editing a key makes it the collector's, and so does clearing one: an object keeps the set of keys the collector typed or cleared, and a lookup never fills those. A lookup never writes `acquired`, money, the condition or a ladder axis, and never an empty title.
- **Grades.** A scale field is set only through its ladder axis (`.axis`), never as a plain field, so the rule that a wanted object has no condition sees every grade.
- **Borrowing.** Only an object added as borrowed can be marked borrowed from someone. Marking one of the collector's own would silently drop it from the counts.
- **When a wanted object arrives,** its priority and price cap are cleared.
- **Places.** Typing a path reuses a place with the same name (ignoring case) under the same parent, and makes the rest. Duplicates made on two devices are merged by the collector, never by `plan` (§3.2).
- **Counts.** Promoting takes one copy off a count, down to zero. A typed collection only takes its own type; a mixed collection takes any.
- **Loans.** Only the collector closes a loan (D-2). Giving back a borrowed object closes the loan and leaves the object marked borrowed, so it still never counts.

### D-39 · The first storage migration

**Decision.**
- **Tables.** The first migration creates the tables M2's commands write: `events`, `collections`, `objects`, `works`, `places`, `persons` and `loans`. They follow `SyncEngine`'s rules: a `TEXT` UUID key `NOT NULL ON CONFLICT REPLACE DEFAULT (uuid())`, a `deletedAt` column, and no unique constraint beyond the key. The rest of PLAN §3.2 (`photos`, `objectEntries`, `ownFields`, `importBatches`, `lookupQueue`, `settings`, `objects_fts`) arrives with the milestone that writes it, each as a new, additive migration, which `SyncEngine` allows. A migration that has shipped is never edited.
- **Rows.** Each projection row keeps its model value as JSON in `data`, and that's what's read back. The other columns (title, ownership, collection, place, dates) are copies for queries and indexes, written from the same value in the same statement. Reading `data` is exact, where SQLite's text dates round to the millisecond.
- **Exactness.** `data` holds JSON written by Foundation's coders, which keep a date's every digit. SQLite's text dates and StructuredQueries' JSON coders keep milliseconds, which made a rebuilt projection drift from the live one on a real clock (review of M2, finding 1). Events keep their whole value in `data` too.
- **Order.** The log replays by `seq`, the order commands ran on this device, whatever the clock did (finding 2). Merging logs from several devices by `at` waits for sync and a device column.
- **Append-only, enforced.** Triggers make SQLite refuse any `UPDATE` or `DELETE` on `events`.
- **`uuid()`** is registered on every connection (`ShelfStore.configuration`), backed by the `uuid` dependency. Apple's SQLite has a `uuid()` of its own, which hid the gap; Linux's doesn't.
- **Writing.** `perform` loads the projection, plans, appends the events, and upserts every row that changed, all in one write transaction. Nothing is ever deleted except by `rebuildProjection`, which empties the projection tables and replays the log. Loading the whole projection per command is fine for v1's shelves; an import batch is one command.
- **Linux.** sqlite-data and GRDB build and pass on Linux once `libsqlite3-dev` is installed, so `TegolaStorage` is part of `linux-core` and `test-linux.sh` (D-32).

### D-40 · What `plan` doesn't check yet

**Decision.** `plan` checks that a key belongs to the object's type, subtype and item level, but not that its value fits the field. It doesn't check the kind (a yes/no in a choice field), a narrowed choice's options, or whether the field is hidden or preset (an edit could set `platform` on a Saturn game). M3's edit form renders `EffectiveType` and only offers valid values, and M3 adds the value checks to `plan`, so an import (M6) can't bypass them either. The review of M2 raised it (finding 11).

### D-41 · tegola-server is ours to change

> Owner: "add in tegola, like in mackoj/telaio, information for the LLM to know that it can work on this webservice if needed when working on tegola".

**Decision.** `mackoj/tegola-server` (Hummingbird 2, generated from `api/tegola-lookup.openapi.yaml`) is the owner's, like the app. A task here that needs the server to change (a new operation, a field, a bug in an answer, a limit) changes it there too, on its own branch and PR, following that repo's `CLAUDE.md` and `tasks/HANDOFF.md`, in the same session when it has access. The contract stays here: change it in this repo first (`scripts/lint-api.sh`), then the server copies it with its `scripts/sync-contract.sh`, and its CI fails while the copies differ. `CLAUDE.md` says so under "Companion repo".

### D-42 · The bytes an App Attest assertion and attestation cover

**Gap.** The contract said `SHA-256(body)` inside the signed string without saying how the digest is written, `path-with-query` without saying whether the base path counts, and `SHA-256(challenge)` without saying which bytes of the challenge (found while writing tegola-server's verifier, its D-5 and D-6).

**Decision.** The signed string uses the method in upper case, the request target exactly as sent with `/v1` included, the timestamp header's text, and the body digest as 64 lower-case hex digits (an absent body hashes as empty). The attestation's client data is `SHA-256` of the challenge string's UTF-8 bytes, exactly as `GET /app-attest/challenge` returned it. Both are now in the contract's text; `AppAttestMiddleware` (M6) builds these bytes.

### D-43 · What counts

**Decision.** A count is the copies of what's owned and kept: a quantity object counts its quantity (12 enamel pins are 12), and wanted, borrowed and let-go objects count nothing (PD-061, PD-070, promise 4). The Shelf header, a collection's meta line and every stat use the one function, `count(_:)`. A collection line counts what's in it, so collection lines add up to the shelf's count.

### D-44 · Settings before the settings screen

**Decision.** `settings` arrives in M3 as its own migration, holding only what the collector changed (PD-161). Each known setting has a fixed row id, because `SyncEngine` allows no unique constraint on `key`. PLAN §5 reads settings through a custom `SharedKey`. Screens read settings with the shelf's own query (`ShelfSnapshot`), and write them through `SettingsClient`: M3 writes one, the last collection used (D-50). The money switch is written only by the You screen (M8), which brings the `SharedKey` with it.

### D-45 · Type tints the palette doesn't name

**Decision.** A type's `gradient` names two colours, and the theme maps each name to a colour (`TegolaTheme.tint(named:)`), so a type file stays data and a future theme can retint types. Six names have no hex anywhere in the archive, so each maps to the palette's nearest colour: indigo → cobalt, claret and plum → pink, oxide → rust, phosphor → yellow, verdigris → teal. An unknown name falls back to sand, so a new type file can't break a screen. If the owner wants those six as colours of their own, they're one line each in `Theme.swift`.

### D-46 · Recording snapshots

**Decision.** References live in `docs/snapshots/<suite>/`, outside every package, because writing into a package mid-run makes xcodebuild reload the package and hang. Separately, an `xcodebuild test` run with a failing test sometimes never exits on this Mac, so `scripts/test.sh ios:<Package>` gives up after ten minutes. A record run (`SNAPSHOTS=record`) records and passes rather than failing. A missing reference outside record mode is still recorded and fails, so CI can't pass on a snapshot nobody looked at.

### D-47 · The Shelf home and the collection screen in M3

**Decision.**
- **Shelf home.** Collections are a 2-up grid of tiles as on board 01, since PLAN §4.0 puts tiles on the Shelf home. F3's "rows" is read as "the same shape for every type". With money off, the banner is board 01's `sellingOff` variant ("Catalogued · N objects" in cobalt); with money on, it's the value in green. The filter pills on board 01 ("For sale" is out of v1) and the header avatar (the You tab covers settings) aren't built.
- **Empty shelf.** It keeps board 02's illustration and type scale, with **Type it** as its only action. The first-piece camera is M5 and **Bring your list** is M6, so each joins when it exists.
- **Not tappable yet.** The wishlist tile shows its count but opens nothing until its screen (F16).
- **Collection screen.** It filters by place, including the places inside it. Status filters wait for statuses (M4). A let-go object leaves the collection's list for the archive.
- **Navigation.** The Shelf tab's stack is the first one, with `AppPath` holding the screens built so far. A route whose screen comes later in M3 does nothing yet. Tapping the Shelf tab while on it returns to its root.
- **State equality.** A feature's `@Fetch` snapshot is the database's state, kept current outside any action, so it's left out of the state's `==`. Tests assert on it directly.

### D-48 · The object screen in M3

**Decision.** The seven slots follow board 04 under PD-013:
- **Hero.** A dark stage with the type's flat hero; the photo joins with T3.9.
- **Spine.** Chips for the subtype, year and grail, the title, the subtitle, then the type's labelled spine lines (paid and value only with money on).
- **Status.** One chip. Clocks and their statuses arrive in M4, so in M3 the slot shows only what the collector should know now: lent to someone, unconfirmed, needs details, wanted, borrowed, let go. Otherwise it's empty.
- **Signature.** The ladder (each part's grade as a bar on the type's scale, better grades longer) and the set (present parts filled, missing ones dashed). Gauge, panel, map and case render with the types that use them, none of which is a v1 type.
- **Fields.** Each field with a value, labelled by the type, AUTO until touched.
- **Actions.** Edit, Photo, and Might let go on what's owned and kept. Lend, Return and Let go join with their sheets (M7, M8).
- **History.** Newest first, only the kinds a person reads (`ShelfEvent.Kind.readsAsHistory`).

### D-49 · The edit form in M3

**Decision.**
- **Order.** The form follows board 13. First the spine, relabelled by the type, with paid and value only when money is on. Then the condition: one grade, or one per ladder part, on the type's own scale. Then every visible field, one control per kind, then the place as a typed path, the notes, and the item level behind "+ Add".
- **Controls.** Text and dims get a text box, number a numeric box with its unit, choice single chips, set multiple chips, yes/no a pair that starts unset, date and event a date picker, year a year box, yearRange two year boxes, list and log an entries editor, money an amount in the object's currency or the reader's. Photo, composite and files show "not editable here yet": photos come with T3.9, and composite and files belong to types that aren't v1.
- **Dates.** An empty date stays empty until the collector picks one, so the app never fills a date by itself (PD-165).
- **Save.** Save sends one `edit` with exactly the changed keys, which is one `edited` history line. A new place is a second command, `setPlace`, and its own history line. A refused save says why and stays open.
- **Value checks (D-40, done).** `plan` now checks every value against its field: the kind, a choice's or set's options (narrowed by the subtype), a scale's steps. `add` fills a subtype's preset values itself, `edit` refuses a hidden field, and a lookup skips one.

### D-50 · Adding by hand in M3

**Decision.**
- **The sheet.** Scan presents Add by hand until the camera exists (M6): the middle slot still presents and never navigates (PD-117). The empty shelf's Type it opens the same sheet.
- **Steps.** Pick one of the four v1 types, then the form: an optional subtype (a platform or format), Add to, and the edit form's fields (`ValuesForm`, shared). Changing the subtype clears the type's fields and grades, because another subtype has other fields and other presets.
- **Add to** points at the last collection used if it takes the type, else the type's own collection, else a new one named by the type (PD-137). The last collection used is a `settings` row (D-44).
- **Save, add another.** It keeps the type, subtype and collection and empties the form, for many objects in one sitting (the M3 exit test). Save closes the sheet.
- **Thing's duplicates.** Thing asks how duplicates count (PD-151). By hand in M3, every Thing is one copy (rows); asking comes with the first-piece flow and the capture tray (M5, M6), where duplicates show up.

### D-51 · Search without FTS5, for now

**Decision.**
- **Search is pure Swift.** It lives in `TegolaModel` (`search(_:in:catalogue:)`) and runs over the projection the screen already holds. Every word must appear somewhere on the object (case, accents and width ignored): the spine, a field, an entry of a list or log, the notes, the place, the subtype. Each hit says which labels matched. It's pure, so it's tested on Linux, and it needs no second copy of the data to keep in step. PLAN §3.2's `objects_fts` and `objectEntries` wait for M9's performance target (results under 150 ms on 2,000 objects): if pure search misses it, the FTS index arrives then, behind the same function.
- **Saved views in M3.**
  - Imperfect: any ladder part at Missing or at the bottom two steps of its scale.
  - Duplicates: two owned, kept copies of one type, subtype and title.
  - Signed.
  - Might let go.
  
  "Digital" and "Also exists on" need works and digital games (M6's import), so they come with them.
- **Filters.** Type, lent out, place, and the archive (let-go objects, so "did I ever own this?" has an answer). Condition and status chips wait for statuses (M4).

### D-52 · Places in M3

**Decision.**
- **Merging.** A merge is one command, `mergePlaces(from, into:)`. Each object in `from` gets its own `placed` history line, then the place folds into the other, its children with it. The merged place stays in the projection, marked `mergedInto`, and leaves every list, so history that names it still reads.
- **Near duplicates.** The app offers a merge for each pair of live places under the same parent whose names are near duplicates (`PlacePath.isNearDuplicate`, M1), and never merges alone (PD-151).
- **When Places shows.** The Places line shows on the Shelf home once two live places exist (F10). A place's screen lists its objects and the places inside it, whatever their type.
- **One target.** `PlacesFeature` holds both the list and one place's screen, which PLAN §5 names separately. They share every dependency and view, so one target saves a package of boilerplate.

### D-53 · What the review of M3 changed

**Decision.**
- **Missing.** It's a ladder step only where the type says `allowMissing`. The form offers it there, `plan` refuses it elsewhere, and the ladder draws it as a dashed, empty rung.
- **Duplicates.** A signed copy is one of a kind, never a duplicate (48, `item.yml`).
- **Empty list entries.** A list or log keeps only entries with something in them. An empty one is no value, so "+ Add entry" then Save records nothing and doesn't make an object Signed.
- **A lookup's bad value.** A value that doesn't fit its field is dropped from the lookup, not a reason to refuse the whole answer.
- **Place merges.** A merge offers both directions; the collector says which name stays (PD-151).
- **Partial saves.** Once Add by hand has saved the object, a place or the remembered collection failing afterwards is reported rather than reopening the save, so a second tap can't add a duplicate. Every error is caught.
- **Money on, nothing valued.** The Shelf home shows the count rather than an empty figure.
- **Search for the owner.** Pure Swift search instead of T3.10's `objects_fts` (D-51) changes that task's acceptance. That's the owner's call, and M9's performance target is where it's measured.


### D-54 · The owner's answers to M2 and M3's readings, and clctn's schema as the reference

> Owner (2026-11-01): "I agree with your decisions and keep in mind that the previous implementations have already fixed a lot of issues and answered a lot of questions regarding the data model, for example mackoj/clctn, which was pretty well advanced on the SQLite database modelling, and fast and accurate too."

**Decision.**
- **Approved.** D-35 (music's per-medium names), D-38 (imported rows confirmed), D-45 (type tints), D-50 (Thing by hand is one copy) and D-51 (pure Swift search for now) stand.
- **clctn's schema first.** Before any storage or query work, read clctn's modelling and port what it already settled, rather than deriving it again. That covers new tables, indexes, search, migrations, import and performance:
  - `docs/architecture/schema.sql`: spine columns plus JSONB fields, `objectEntries`, the FTS5 `objectSearch`, places with a normalised key, `historyEvents`, `typeMigrations`, `importBatches`, `counters`, and the indexes;
  - its ADRs, 0006 to 0008;
  - `docs/engineering/pointfree.md`;
  - `Tests/DatabaseTests/SchemaTests.swift`.

  A choice that departs from it gets a D-entry saying why. D-39's JSON `data` columns and D-51's search are the two departures so far. When M9 measures search, or earlier if a screen needs it, the starting point is clctn's `objectSearch`.

### D-55 · A revoked App Attest key stays revoked

**Gap.** The contract told the app to register again on `unknown-key` "if the key was revoked or the server lost it", while its `Forbidden` response, tegola-server's D-7 and its stores answer a revoked key with `403` on every call and refuse to register it again (found by tegola-server's M2 review).

**Decision.** `unknown-key` (401) means the server lost the key: register it again. A revoked key gets `403` and stays revoked; the app generates a new App Attest key and registers that one. The contract's `registerAttestKey` description says so; `AppAttestMiddleware` (M6) follows it.

### D-56 · Disc rot on video games, and what a clock says

> PD-018: "Optical games ship without a disc-rot clock. A clock that fires on a healthy disc is worse than none."

**Gap.** `video-game.yml`'s Saturn and PS1 subtypes named `discRot` (from page 48), which contradicts PD-018 and
PLAN F15.

**Decision.**
- **Video games hold `discRot` pending** (`discRot-pending`, D-37): named, shown nowhere, until there's evidence.
  Music's CD and Video Media's discs keep it. PD-018 is about games, and a CD's "last checked for rot" is a care
  habit its collectors already have.
- **What clocks read.** Clocks are pure functions of an object (T4.1). The projection keeps the latest date of each
  logged kind of care (`ShelfObject.latestLog`), so a clock never needs the event log. The kinds are `CareKind`'s:
  serviced, cleaned, checked and battery swapped.
- **What each clock says** (parameters from `ClockLibrary`):
  - **`saveBattery`** goes to watch 3 years before 25 years from fitting, and to act after. "Fitted" is the later of
    the field's date and a logged swap, or the release year.
  - **`discRot` and `mediaRot`** go to watch when a check is due, never act. Disc rot can't be told from folklore
    (PD-018), so the most the clock says is "worth a look".
  - **`codeExpiry`** goes to watch 60 days before expiry, and to act after it.
  - **`drinkingWindow`** goes to watch a year before the window opens. While it's open, it's good: One Roof's "Drink
    it". In its last year it's watch again, and after it, act.
  - **`serviceRisk`** goes to watch after one service interval, and to act after two.
- **No basis, no signal.** A clock with nothing to estimate from (no year, no date) says nothing, rather than a guess.

### D-57 · How an object's status is read (D-15, refined for clocks)

> PD-016: "Every derived state maps onto fine · good · watch · act · gone. The only cross-type number is 'needs
> attention'."

**Gap.** D-15 named the labels but not how clocks, loans and identity combine, or what counts as needing attention
when the Today strip already counts what's to tidy.

**Decision.** `StatusReading.derive` picks the most urgent candidate, the earlier one between equals:

1. **Gone.** Let go: nothing else is said.
2. **Act.** An overdue loan, then a clock at act.
3. **Watch.** A clock at watch, then needs details, then unconfirmed.
4. **Good.** A clock's good moment ("Drink it").
5. **Fine.** Lent and not due ("Out"), or settled.

- **Need attention counts signals only**: clocks at watch or act, and overdue loans. An unconfirmed object's chip is
  watch, but it's counted by "N to tidy", never twice.
- **Clocks run only on objects the collector owns and keeps.** A wanted or borrowed object's care isn't theirs.
- **A dismissal** (`dismissSignal`) records the status the collector saw. The clock stays hidden until it says
  something more urgent, so a battery dismissed at watch comes back when it reaches act.
- **Wording.** `SignalListTests.phrase` words every reason in English for the golden list. The screens' String
  Catalog keys follow the same cases (T4.5).

### D-58 · How the first piece's type is guessed

> PD-166: "the type is inferred rather than asked."

**Gap.** PLAN §2 gives the inference to `ExtractionClient` (Foundation Models), but a model that answers with a type
id can only pick among ids it's told about, and it can't say what a type is called in a description it didn't write.
Without Apple Intelligence, there's nothing to infer with at all.

**Decision.** The type files say what names them. Each has a `recognise:` list of words ("wristwatch", "board game"),
and each subtype has its own ("n64", "nintendo 64"). `Catalogue.guess(from:)` scores a description against them: one
point per word found, matched whole and in order, without case or accents, plus the best subtype's points. The model
only describes the piece in words. The same guess reads the text a capture recognises, or what a collector types in
*What is it?*.

- **Nothing named, or two types named equally, is no guess.** The screen asks *What is it?* rather than picking.
- **Thing is never guessed.** It's what's left when nothing is.
- **No word names two types.** A shared word would make one of them unguessable; a test refuses it.
- **Every type is guessable, enabled or not.** A guess says whether its type has shipped, so a watch is recognised
  as a watch and saved as a Thing that waits for the type (46, 2B; D-59).

### D-59 · The first piece: one write, a waiting Thing, and what the payoff says

> 46: "If the type hasn't shipped yet, the user becomes a tester for it." PD-031: "A shipped type offers migration
> and never imposes it."

**Gap.** Page 46 says a watch is "saved safely as a Thing" and that testers' "pieces upgrade automatically", but not
how a Thing remembers what it is, where **Count me in** is kept, or what the payoff says when a clock has nothing to
say yet.

**Decision.**

- **One write.** `ShelfCommand.firstPiece(draft, story:catalogue:)` is an `add` into a new collection named by the
  type file (`name.collection`, PD-137), with the `firstPiece(story:)` origin. `plan` refuses it on a shelf that has
  ever had an object (`notTheFirstPiece`): onboarding happens once. Letting the piece go doesn't bring it back.
- **The story is the collector's words.** The chip they tapped and the line they typed are stored as one trimmed
  text, in the language they answered in, like any note. It's the `added` event's origin, so it's the History slot's
  first line, and it's never `acquired` (PD-165). An empty story is allowed: nothing on the screen is required.
- **A waiting Thing.** `ObjectDraft.recognised(as:)` turns a guess of a type that hasn't shipped into a Thing with
  `awaitingType` set. It keeps only what every type means the same way: the title, the maker, the year and the notes.
  `plan` allows `awaitingType` only on a Thing, and only for a type that exists and isn't enabled
  (`cantAwaitType`). `Shelf.waiting(for:)` lists those pieces, for the migration a shipped type offers (v1.x).
- **Count me in** is a setting, not a shelf change (`SettingKey.typeTesters`, read as `TypeTesters`): it describes
  the collector, not an object, and it has no history. So is **Just look around first** (`firstPieceSkipped`).
  `ShelfSnapshot.opensOnFirstPiece` is true while the shelf has no object and it hasn't been skipped.
- **The payoff** (`FirstPiecePayoff`) is the most urgent thing the piece's clocks say now, at any status, good
  included. When they say nothing yet, it's the earliest date one will (`Clocks.firstSignalDate`): page 46's wine,
  "Not yet. Soon." A piece with no clock shows its story alone. T4.6's first notification reads the same date.

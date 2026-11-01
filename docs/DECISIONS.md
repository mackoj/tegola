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

### D-56 · The clocks' thresholds (M4)

**Gap.** PLAN §3.3 and F15 name the clocks and their parameters, and F15 gives the save battery's 25–35 years. Nothing says where *watch* turns to *act* for any of them.

**Decision.** A clock's reading is *good*, *watch* or *act* (`Signal`, `TegolaModel`), and moves at fixed thresholds:

| Clock | *watch* from | *act* from |
|---|---|---|
| `saveBattery` | 25 years since the swap, the fitted date or the release year | 35 years |
| `codeExpiry` | 60 days before `codeExpires` | the expiry date |
| `drinkingWindow` | a year before the window opens | the window's last year |
| `serviceRisk` | the interval (24 months) since the last known service | twice the interval |
| `mediaRot`, `discRot` | the check interval since the last backup or check (D-58) | twice the interval |
| `unfinished` | 12 months Playing | never |

A clock with nothing to read gives no signal: no year, no date, no known service. The parameters live in `ClockLibrary`; dismissals (risk R2) are how they get tuned.

### D-57 · Disc rot held back, code expiry, and the unfinished game

**Gap.** `video-game.yml` gave Saturn and PlayStation `clock: discRot`, against PD-018 (no disc-rot clock in v1). F15's `codeExpiry` "applies to code cards", but no field held an expiry date. D-20's opt-in "started long ago, never finished" clock wasn't in the library.

**Decision.**
- **Disc rot.** Saturn and PlayStation name `discRot-pending`: the clock is named and shown nowhere until there's evidence (D-37).
- **Code expiry.** Video games gain `codeExpires` (a date) and name `codeExpiry` for every game. Without a date there's no signal, so it costs a cartridge nothing.
- **Unfinished.** The library gains `unfinished`, which reads when `playStatus` last turned to Playing. It's `isOptIn`: no signal unless the collector turns it on (a setting through `SettingsClient`; the toggle waits for You, M8).

### D-58 · A media check is a backup

> Owner (2026-11-01), on `mediaRot` and `discRot` never reaching *act*: "maybe try to make a backup of it".

**Decision.** What a collector does about ageing media is back it up. The media clocks reach *act* at twice their interval, and their action is **Make a backup**, logged as a `backedUp` event (`logEvent`). A backup or a service resets them.

- **They start at the first backup.** The 200-object shelf (T4.9) showed that counting from the year a tape was made puts every cassette and every CD in the feed, which no collector would agree with. So a media clock has nothing to read until a backup or a check is logged. Until then the object offers **Make a backup** in its actions without a signal. After one, it reminds at 2 years (*watch*) and 4 (*act*).
- **Disc rot stays pending on v1's types** (D-57), music's CDs included. In v1, music's cassettes are the media clock's only users.

### D-59 · Status, and what the clocks read

**Gap.** D-15 says status is derived in the model, from One Roof's rules, but One Roof only gives the five swatches and "needs attention = watch or act". D-48 left the slot's M4 rules open. A signal needs an object's service, backup and play history, and the screens read a projection with no events.

**Decision.**
- **The rule** (`ObjectStatus.derive`): let go is *gone*. Wanted and borrowed objects have no signals and are *fine*: they aren't the collector's to look after. An owned object takes the most urgent of its showing signals; a loan out past its due date raises it to *act*; with no signal it's *fine*. To tidy, needs details and lent keep their M3 labels in the slot (D-48) and don't change the swatch.
- **Counted once.** An object that's only overdue is on the Today strip's overdue line, not *need attention*. One that also has a clock signal needing attention is on both, so the count matches the feed it opens. The strip counts objects; the feed lists signals, so an object with two shows as two rows.
- **The Lent chip** keeps M3's *watch* swatch as a label of the collector's state (*act* once overdue). The status filters read the derived status, which for a lent object with no signal is *fine*.
- **What the clocks read** is kept on the object as `signalState` (last service, last backup, playing since), written by `apply` from `logged` and value events. Objects are stored as JSON (D-39), so it needs no migration, and a replay rebuilds it. A whole shelf's signals (`ShelfSignals`) then need no history.
- **The calendar** is a dependency, like the date: a clock's year boundary comes from `\.calendar`, never `Calendar.current`.

### D-60 · Dismissals

**Gap.** F15 and risk R2 say every signal can be dismissed and the dismissal is logged, so the clocks' parameters can be tuned. Nothing says how long a dismissal lasts, or what it records.

**Decision.**
- **The command** is `dismissSignal(object, signal)`. `plan` takes it only for an owned, kept object and a clock the type runs and doesn't hold back. It re-reads that clock at the command's moment (`PlanContext.calendar`) and refuses unless the reading is showing, needs attention and has the status the collector saw. It records that reading, not the caller's copy. An opt-in clock counts as on here, since its signal was only seen if it was.
- **The event**, `signalDismissed`, records the clock, the status it read and the library's parameters in force: shape, never the object's content. It steers screens, so it isn't in History's main kinds; where History does show it, it reads "Estimate dismissed".
- **How long.** A dismissal hides that clock's signal until the reading gets more urgent (*watch* to *act*) or there's new evidence for that clock: an event it reads (a service, a backup) or a change to a value it reads. Each clock lapses alone, so a battery swap doesn't bring back a dismissed code expiry.
- **Storage.** The dismissed clocks live in the object's `signalState` (D-59), so there's no new table. clctn's schema has no equivalent to port, and a table would be one more thing for CloudKit sync to carry. The event log keeps every dismissal for tuning.

### D-61 · Clock notifications

**Gap.** F15 says notifications are "offered once, in plain words, when the first clocked object arrives", and PLAN §5 names `NotificationsClient`. Nothing says where the offer appears, when notifications fire, or how they follow the signals.

**Decision.**
- **The offer** is a card on the Shelf home, not a system prompt out of nowhere. It appears once an owned object has a signal, any status, so a clock with something to read. Every game names `codeExpiry`, but a game with no code date isn't clocked. It stays until the collector answers. **Yes, tell me** asks the system for permission; **No thanks** puts it away. The answer is a setting (`notificationsOffer`), so it's asked once.
- **What's scheduled:** one notification per signal's next change (`changesAt`): the day it turns *watch* or *act*, at 10:00 in the collector's calendar, or a minute later if that's today and 10:00 has passed. A dismissed signal is scheduled for the day it would get more urgent than when it was dismissed, the day it shows again. It's titled with the object and says an estimate thinks it's due, nothing more. At most 50, the soonest, because iOS keeps 64 pending.
- **Following the signals.** With the offer accepted, each time the Shelf home appears the clock notifications are replaced from the signals then. A swap, a backup, a dismissal or an edit since the last time moves or removes them. Other kinds (loan due, M7; the weekly nudge, M8) use their own id prefix and aren't touched.
- **Opt-in clocks** are a setting too (`optedInClocks`), read with the shelf. Its toggle waits for You (M8).

### D-62 · How the first piece's type is guessed

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
  as a watch and saved as a Thing that waits for the type (46, 2B; D-63).

### D-63 · The first piece: one write, a waiting Thing, and what the payoff says

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
- **The payoff** (`FirstPiecePayoff`) is the most urgent signal that needs attention (*watch* or *act*). When every
  clock reads *good*, it's the soonest `changesAt`, the day one turns *watch*: page 46's wine, "Not yet. Soon." A
  piece with no clock, or none with anything to read, shows its story alone. The clock notifications (D-61) read the
  same `changesAt`.

### D-64 · An import's rows, and what its undo removes

> PD-047: "Import never overwrites, merges or invents. … Nothing is marked confirmed. The whole batch can be undone
> for 30 days." PLAN F9: "The import creates **one collection** named after the file."

**Gap.** D-38 read an imported row as confirmed ("the collector's own list, mapped by them") and left M6 to change
it. D-12 says undo keeps what the collector touched, but not what touching is, and the projection never removed
anything.

**Decision.**

- **Unconfirmed.** Every imported row lands unconfirmed, as PD-042 and PD-047 say; this replaces D-38's reading for
  `.imported`. A collector-typed object and the first piece stay confirmed.
- **One command.** `ShelfCommand.importBatch(ImportBatch)` makes one collection (typed when every row is one type,
  mixed otherwise), a `batchImported` record, and an `added` per row, all carrying one batch id. A row the rules
  refuse refuses the batch, so nothing is half-imported: an importer's job is to send only rows `plan` accepts, with
  anything it couldn't read kept in the note.
- **Touched** means any event on the object from the collector or a capture after it was added: an edit, a photo, a
  place, a loan, a confirmation, a care line, a copy taken out of a count. A lookup's answer and the import itself
  don't count. The object carries it (`ShelfObject.imported`), so `plan` stays a function of the shelf.
- **Undo** is the collector's, within 30 days of 24 hours (`ImportBatchRecord.undoWindow`), once. It appends one
  `batchUndone` event naming the objects it removed and the ones it kept, so the summary can say "3 kept because you
  changed them". The removed objects leave the projection; their rows are marked `deletedAt`, never dropped, and the
  log keeps every event. The batch's collection goes too once nothing is left in it. This is the one way an object
  leaves the shelf, and the promise tests check it removes only untouched rows of that batch.
- **`importBatches`** is clctn's table less the mapping and the report, which are the importer's plan and aren't
  kept. It has no foreign key to its collection, which an undo can remove.

### D-65 · How a cell's notes are read without the on-device model

> 49, "Cell → item": "It must never invent a value: anything it can't read goes into note, untouched." PLAN F9:
> "parts and condition from the notes, signed, bundles split by "/", "doublon" as a second copy, digital kept apart."

**Gap.** Page 49 shows what nine of Jeux's cells become, but not the rules behind them, and some of its readings
invent: "Mario 64 (boite endommagé + cartouche)" gets *manual: missing*, which the cell never says, and a typo is
"fixed" in the title.

**Decision.** `CellExtracting` is the reader's interface. Foundation Models implement it on the Mac (T6.10);
`NoteReader` is the rule-based one, used without Apple Intelligence and pinned by the tests. Its readings:

- **The title** is the text outside the brackets, as written: typos are matching's to fix (T6.6), never the reader's.
- **A listed part** ("cartouche + manuel") fills the type's What's inside slot when it has one, and a cart or disc the
  media field when no subtype presets it. **An unlisted part is not Missing**: a loose cart isn't written as missing
  its box. That keeps Jeux's Imperfect count at page 49's three instead of every loose cart.
- **Damage** ("endommagé", "abîmé", "ko", "HS") grades the part's ladder axis at the scale's worst step (Poor), and
  **"manque <part>"** grades it Missing. A missing thing that isn't a part ("manque cd audio") is noticed as imperfect
  and stays in the note.
- **"dédicace JDG"** is the item level's Signed, by JDG. **"doublon"** marks the cell itself as the second copy:
  Jeux has "Fantasy zone (cartouche)" and "Fantasy zone (cartouche) doublon", two objects, one noticed as the
  duplicate (49 §03), so a doublon never makes an object of its own. **"/"** in the title is a bundle (`contains`);
  "+" in a title isn't ("Tony Hawks 1+2").
- **"digital"** is noticed and asked about in the exceptions queue (keep, wishlist, leave out; 43 Q4), and stays in
  the note, since no field says it.
- **Anything else** ("platinum", "four players", "cartouche x2") goes into the note, as written, joined by " + ".

### D-66 · The two layouts a spreadsheet comes in

> PLAN F9: "the layout (a column per platform, no title header) maps headers to subtypes". PD-048: "Only "name" is
> required, and any column order, separator, encoding or date format is accepted."

**Decision.** `SpreadsheetImporter` reads each sheet as one of two layouts.

- **A grid** is a sheet where at least two headers each name exactly one subtype of a v1 type, by its key, label or
  `recognise` words, whole: "Game Boy advence" isn't Game Boy. Every non-empty cell is an object of that type. A
  header that names a subtype becomes it, and the sentence shows it as a dashed chip when the file spells it
  differently (Ps1 → PlayStation). Any other header is written, as the file spells it, into the field every subtype
  presets (video games' platform), and names the row's shelf. Renaming "Game Boy advence" to GBA is matching's job.
- **A list** is anything else: the first row is headers, mapped with clctn's spine aliases (English and French) and
  the type's field keys and labels; a text or choice field takes a value only if it fits. The type is the one the
  file's name and headers name (`Catalogue.guess`), if it ships, or a Thing. Without a title header the first column
  is the name. A column nothing maps, or a value that doesn't fit, goes into the note as "Header: value", so nothing
  is dropped. A year is read only as four digits; `acquired` is never read from a list until the mapper assigns it
  (D-14).
- **Sheet tabs.** A tab named like a wishlist ("Recherché", "Wanted", "Envies") is wanted objects; their grades stay
  in the note, since a wanted object has none. A sold tab ("Vendu") needs a let-go row in `ImportBatch`, which T6.10
  adds with the screens; until then it imports as owned.
- **Every row is one `plan` takes.** `RowBuilder` dry-runs each draft; one it would refuse falls back to its cell,
  as written, as the title. Jeux has none.

### D-67 · The `tegola.csv` template's columns

> 49 §03B: "A template we publish, with one row per item and fixed headers. … it's the same format the app exports."
> Its sample: `type,platform,title,region,parts,condition,signed_by,note`.

**Gap.** Page 49's columns are a video game's. Export (M8) has to write every type's fields, and a template that
changed per type wouldn't be one template.

**Decision.** `TemplateFormat.columns` are fixed, in this order: `type, subtype, title, subtitle, year, parts,
condition, signed_by, contains, note`. A file may leave out any of them except `type` and `title`, but keeps the
order. Every header after them is a field key of the row's type (`region`, `catalogNumber`), so Export adds a column
for each field it has to write and the importer needs no change. `type` is the type's id and `subtype` its key, never
a label: the template is for round trips, not for typing by hand. `parts`, `signed_by` and `contains` are lists
split by `|`; `condition` is the object's grade, or `axis:grade` pairs for a ladder (`boxCondition:Poor`). A value
that doesn't fit its field goes into the note as `header: value`, nothing is guessed, and nothing goes through the
cell reader. An unknown type is a Thing with `type: …` in its note; a type that hasn't shipped is a Thing waiting
for it (D-63). M8 adds what Export needs beyond these (ownership, quantity, place, the money and dates the collector
typed) as fixed columns after `note`, on both sides at once.

### D-68 · What a Discogs export becomes

> PLAN F9: "`DiscogsCSVImporter`: the CSV file Discogs lets you export." music.yml: "The Goldmine scale, which Discogs
> returns for every medium here."

**Decision.** A file whose header has Discogs' `Catalog#, Artist, Title, Label, Format, release_id` is certain to be
an export. Each row is a Music release. The first word of Discogs' format picks the subtype and Music's format
("2xLP" → Vinyl, 2×LP; "CD" → CD; "Cass" → Cassette; MiniDisc, reel, 8-track and DAT → Other); a format Music doesn't
name, and the descriptions after it ("Album, RE"), go into the note as `Format: …`. The media grade is the object's
condition and the sleeve grade its packaging condition, on Goldmine's words; "No Cover" is Missing, and "Good Plus",
"Generic" and "Not Graded", which Music's scale doesn't have, stay in the note. "Nirvana (2)" is Nirvana: the number
is how Discogs tells two artists apart. `Released` of 0 and `Catalog#` of "none" are empty. The folder (unless
Uncategorized), the rating, the release id, the date added and any custom field go into the note: none is a Music
field, and **Date Added** is when the release was catalogued on Discogs, never `acquired` (D-14). The release id is
there for matching to use (T6.6).

### D-69 · Candidates, enrichment and the lookup queue in the model

> PLAN §7: "A result never writes. It creates an enrichment proposal … applying it is a `ShelfCommand.applyEnrichment`
> that only fills empty fields (PD-045)." "At most 5 attempts, then the row goes to "needs details"."

**Decision.**

- **`LookupCandidate`** is the contract's `Candidate` in the model's terms: release id, type and subtype, the values
  as the object would hold them, confidence, reasons and sources. `TegolaClients` maps one to the other (T6.8), so no
  screen sees a generated type. Its **strength** is strong from 0.9, likely from 0.6, weak below; only strong is in
  **Confirm all** (F8). The cut-offs are constants until recorded answers say otherwise.
- **An enrichment proposal is what `applyLookup` would write**, computed by planning it on the current shelf: so the
  rule that a lookup fills only empty keys and its own AUTO ones, never a typed or cleared key, `acquired`, money or a
  grade (promise 1), lives in one place. Keys the object's type doesn't have, and every candidate of another type,
  are left out: that's not enrichment but a different identity, which F7 asks about. Applying a proposal is
  `applyLookup` with the keys the collector kept, from the lookup source, so they stay AUTO until touched. There is
  no separate `applyEnrichment` command.
- **`LookupQueue`** is pure: oldest first, five attempts with a 30-second backoff that doubles, then *needs details*.
  A `429` or `503` waits for its `Retry-After` without spending an attempt. Its state isn't shelf history, so it's
  a `lookupQueue` table, not events. `ShelfStore.perform(_:context:lookup:)` queues a capture's identifier in the
  same transaction as the object it added; a request goes when its object does.

### D-70 · What counts as "you already own this"

> F7: "Every match says, unprompted, whether you already own it or another print of it, and lists related objects
> (the manifest's `related` keys). A look-alike offers three choices … It asks only when unsure."

**Decision.** `LookAlikes` compares a draft with what the shelf keeps (let-go objects aside), by type and by title
without case, accents, width or extra spaces:

- **Owned**: owned, same subtype. This is the only case that asks, with **Open it**, **Another copy** and **Add as
  new**. Another copy raises a count (PD-020) or adds its own object in the same collection; opening writes nothing.
  No choice merges (PD-151).
- **Another print**: owned, another subtype (or none). Said, not asked: the PAL and the Japanese copy are two
  objects (video-game.yml, `duplicates: rows`).
- **Wanted**: on the wishlist. The screen offers "it arrived" (D-13) instead of adding a second object.
- **Related**: up to five owned objects sharing a value of a key the type file lists as `related` (the artist, the
  publisher, the designer, the series).

The server's match buckets are `MatchOutcome`: matched, ambiguous, unknown. Only ambiguous goes to the exceptions
queue, never as a gate; matched is an enrichment proposal the collector confirms; unknown stays as written.

### D-71 · Identify: a photo lookup in the contract

> PD-118: a photo leaves the phone only through Identify, and the camera says plainly when it does.

**Gap.** PLAN §7 kept Identify out of the contract and hidden in v1. The owner asked for it on 2026-11-01: an object
should be findable from words, a photo and a barcode, in any combination.

**Decision.**
- **One endpoint for everything but a bare barcode.** `POST /types/{typeID}/identify` (`identifyObject`) replaces
  `searchObjects`, which the owner removed (contract 0.2.0): words alone did the same through both.
  - Without a photo, the body is the hints as JSON: title, subtitle, OCR text, catalogue number, barcode, year,
    subtype, region. D-33's rule carries over: at least one of title, text, catalogue number or barcode, checked by
    the server (`400`), not by the schema.
  - With a photo, it's `multipart/form-data`: the JPEG in `image`, the same hints in `hints`.
  - It answers a `LookupResult`. A candidate the photo supports says so with the new `image` reason.
  - `lookupBarcode` stays: a barcode alone is a GET that HTTP caches can answer for everyone.
- **The photo**, as PD-118 asks:
  - it's sent only when the collector turns **Identify?** on for that shot, and the switch is off by default;
  - it's one JPEG, cropped to the object where the camera can, at most 2048 px and 2 MiB, with EXIF, GPS and every
    other metadata removed;
  - the server uses it for that answer and drops it: no storage, no log, no cache, and no source that keeps it.
- **Never queued.** Identify needs a signal. Offline, the shot saves with what's known, and its barcode or text
  lookup queues as before (D-69). A photo never sits in the queue waiting to leave.
- **The server** chooses how to match an image, per type, as it does for every other source (PLAN §7). Until it has
  a source for a type, it answers from the hints alone, or with no candidates.

### D-72 · The first piece's screens, and how a piece is described

> PD-166: "the type is inferred rather than asked." PLAN F2: four screens, and *What is it?* says why it can't go on.

**Gap.** Page 46's board is missing from the archive (`docs/design/BOARDS.md`), so its layout, its story chips and
what *What is it?* offers are unwritten. PLAN §2 gives the inference to Foundation Models, but iOS 26's model reads only
text, and v1 runs on iOS 26.

**Decision.**
- **Describing a piece** (`ExtractionClient`, D-62): the model says a name, a few words for what kind of thing it is,
  and a year when it's printed or well known. `Catalogue.guess(from:)` turns the words into a type; the model never
  picks one.
  - On iOS 27, where the on-device model reads images, it gets the photo itself with the text Vision reads from it.
  - On iOS 26, it gets Vision's text and the image classifier's confident labels instead.
  - Without Apple Intelligence, a photo gets Vision's labels as words and no name, so *What is it?* asks for one. A
    typed name stands as it is.
  - The photo never leaves the phone here: describing is on-device. A shot and a library photo alike are re-encoded at
    2048 px, which drops their metadata, location included, before they're described or stored.
- **The year** goes on the piece, so its clocks have something to read: page 46's "running since 1998" is the save
  battery reading the year. It's written only once the collector has seen it: a chip on *Is this it?*, and an editable
  field on *What is it?*. A year the model reads from a typed name isn't shown, so it isn't kept. Nothing else the
  model says is written.
- **What is it?** has the name field, dashed and focused, and *It's…* chips: v1's three types, the guessed type when
  it hasn't shipped, and Thing (shown as its hobby name, "Something else"). The guess is picked; the collector can pick
  another; the guess reads the description's words with the typed name, so a guess from the photo survives typing.
  **Next** is disabled until there's a name, and a line under it says so. With no type picked and the model
  available, **Next** asks the model what kind of thing the name is; with none, the piece is a Thing.
- **How did it come to you?** offers five chips (A gift, I bought it, Handed down, I found it, Had it since I was a kid)
  and a line. The story is the chip's words and the line, joined by " · ", in the collector's language (D-63).
- **The payoff** says the signal (with ESTIMATE) or "Not yet. Soon." with the month it'll change, then the story, three
  empty slots, **One at a time** and **That's enough for today**. One at a time closes onboarding and opens Scan, once
  the cover has gone.
- **The empty shelf** offers **Scan your first object**, which opens the first piece again, and keeps **Type it**.
  **Bring your list** waits for M6's import.
- **Ways out.** After the first screen, **Close** returns to the shelf as it is; onboarding comes back next launch if
  the shelf is still empty. A save runs once. If the shelf gained an object since onboarding opened (another device's,
  through sync), `plan` refuses the first piece, and the piece is saved as an ordinary typed add into its type's
  collection, with the story as its note.
- **When it opens:** at launch, while `opensOnFirstPiece`. The app reads the shelf once on appear to decide, and
  doesn't reopen onboarding later in the session.

### D-73 · The lookup client, its worker, and where an answer waits

> PLAN §7: "A result never writes. It creates an enrichment proposal." "`RetryMiddleware` honours `Retry-After` …
> by handing the request back to the queue, never by sleeping in the call."

**Gap.** D-69 made the queue pure and the answer a proposal, but nothing kept an answer until the review queue shows
it, and PLAN §7 doesn't say where the server's address and a simulator's debug token come from.

**Decision.**
- **An answer waits on its request.** `LookupQueue.Outcome.answered` carries the candidates, and the request keeps
  them (`answer`) in its `lookupQueue` row's JSON: no new table and no migration. The review queue reads them from
  there; nothing touches the shelf until the collector applies a proposal (D-69).
- **No retry middleware.** The generated client's typed outputs already say `429` and `503`, so `LookupClient` turns
  them into `LookupFailure.retryAfter(seconds)` and the queue waits without spending an attempt. Other failures spend
  one; `4xx` refusals too, so a request the server keeps refusing ends in *needs details* after five.
- **A queued request** is a barcode lookup when it has a barcode, and `identifyObject` with the text or catalogue
  number otherwise (D-71). A photo is never queued.
- **The worker** runs from the app: when the network is there (`ReachabilityClient`, `NWPathMonitor`), it drains
  every ready request once, oldest first, then sleeps until the next is ready (at most 15 minutes) and drains again.
  It restarts when something is queued.
- **App Attest** (`AppAttestMiddleware`): the key id is kept with `mackoj/swift-keychain`
  (`KeychainKey.appAttestKeyID`). A first call registers a key; a `401` naming an unknown key registers once more and
  retries once. The `appattest-environment` entitlement is `development`; App Store and TestFlight builds use
  production whatever it says.
- **Configuration.** Release builds call the production host. Debug builds read `TEGOLA_LOOKUP_URL` and
  `TEGOLA_DEBUG_TOKEN` from the scheme's environment, so no token is ever in the bundle; with a token, calls carry
  it instead of an assertion (contract, security step 3).

### D-74 · Bringing a list on the phone

> PLAN F9: "the one sentence with rename, **Build my shelf**, **Something's off** (the column mapper), the payoff,
> undo." T6.10: "`ExtractionClient`'s cell extraction (Foundation Models, 20–30 cells a call) behind `CellExtracting`."

**Gap.** F9 doesn't say which reader runs on a device with Apple Intelligence, what **Something's off** offers before
a column mapper exists, or where the server's match answers go.

**Decision.**
- **Cells are read by `NoteReader` on every device, for now.** It meets the exit numbers on Jeux (485 rows, 12 to sort,
  2.5%), it's pinned by its tests, and it never invents a value (D-65). The on-device model would be a second reader
  whose mistakes no test can pin; it waits until it's measured against Jeux and found to do better. `CellExtracting`
  stays the seam.
- **Something's off** offers the other importers that recognise the file (template, Discogs, spreadsheet). The column
  mapper, for a spreadsheet whose headers no alias names, is a follow-up.
- **One write.** **Build my shelf** sends `importBatch` from the import source, with the collection as renamed; every
  row lands unconfirmed (D-64). The payoff counts what the notes said (damaged or missing, second copies, signed), the
  rows to sort, and, once matching is done, the rows the server matched. **Undo** is the batch's `undoBatch`, and says
  how many it kept because the collector changed them.
- **Matching runs after the write,** 50 rows a call per type. A match or a question is kept on its object as an
  answered lookup (D-73), so the review queue shows it; a row nobody knows, and every row when the server can't be
  reached, stays as written (49 Q2). Matching never holds the import up.
- **Where it starts:** Add's **Import a list** and the empty shelf's **Bring your list**. Opening a file from the
  share sheet needs document types in the app's Info.plist, which the generated project doesn't write yet: a follow-up.
- **Journey 2's UI test** opens the import with `--import-fixture <path>` in debug builds, since a UI test can't drive
  the system file picker.

### D-75 · The review queue, and "you already own this"

> PLAN F8: "grouped rows with why, **Confirm**, **Fill in**, **Confirm all** for strong matches only." F7: "Every match
> says, unprompted, whether you already own it … never a merge (PD-151)."

**Gap.** F7's three choices (open yours, another copy, add as new) are for an object about to be added. Since M6 a
capture is saved before any network (PD-046), so by the time a match arrives the object is already on the shelf.

**Decision.**
- **`ReviewQueue`** (model, pure) lists every unconfirmed or needs-details object with its answers, most confident
  first. Groups: **strong** (a strong candidate that fills something: the only rows **Confirm all** takes), **to look
  at** (any other answer; two or more ask "Which one?"), and **as you wrote them** (nothing proposed).
- **Confirm** applies the chosen candidate's proposal from the lookup source (only empty keys; AUTO until touched,
  PD-045), then confirms from the collector. A needs-details object with no title goes to **Fill in** instead.
- **"You already have this one"** shows on a row whose candidate matches an owned object, with **Open yours**. Nothing
  is merged or removed: if it's the same thing, the collector lets the new one go from its screen. **Another copy**
  and **Add as new** are what confirming already does, so the row doesn't repeat them.
- **Where it opens:** the Today strip's *N to tidy* line (`Route.review`), and the capture tray's "Confirm it in
  Review".

### D-76 · People: what the Activity tab and a person's page read, and how a return is written

> PLAN F13: "The return asks how it came back, and that goes into history … Each Person has a page with what they hold
> now and a track record … It's the only tab with a badge, and the badge is gone when nothing is due." D-3: "`lent` and
> `returned` events carry the person's id and name at the time."

**Gap.** D-3 wants the name at the time so a rename doesn't rewrite history, but v1 has no way to rename a person.
Board 19's "return rate 4 / 5" doesn't say what it divides by. Board 20 offers three answers to *How did it come
back?*, where the model had one free-text condition.

**Decision.**
- **Read models** (`People.swift`, T7.1): `Activity` lists loans out (overdue first, then the soonest due, then no
  date, the longest out first), what came back, who holds what, and what's borrowed in. Its **badge** counts only
  overdue loans and is nil at zero. `PersonRecord` gives what the person holds, what they lent you, every loan both
  ways, **returned out of lent**, and the average whole days out over the loans that came back. With no history it
  says nothing: no rate, no average. `Shelf.recentPeople` puts the most recently used names first.
- **The name at the time** comes from the loan's person. Since a person can't be renamed in v1, that's the name they
  had, and no event field is added. If renaming comes, `returned` and `gaveBack` gain the name then, as optional
  associated values.
- **A return** (T7.2) takes `cameBack` (*same shape*, *damaged*, *something missing*, or not said) and the
  collector's words, trimmed; blank words are none. Both live on the loan's JSON and on the `returned` event, where
  `cameBack` is optional, so events written before M7 decode unchanged. The history reads *Back from Dara, closed by
  you · damaged · Sleeve torn*: "closed by you" is how it says one-sided (PD-160).

### D-77 · The system tab bar, and one place for shared actions

> The owner, 2026-11-01: "change the tabbar to the native iOS one; centralize all the button and tabbar action in one
> place to prevent duplicates in the design system."

**Replaces.** `docs/design/BOARDS.md`'s PD-117 note ("keep the board's geometry"): board 01's drawn bar with the
raised yellow Scan button is gone. PD-117's five tabs, their order rules (`TabBarLayout`) and Scan presenting rather
than selecting all stay.

**Decision.**
- **The tab bar is SwiftUI's `TabView`** with one `Tab` per `AppTab`, in the collector's order, tinted with the
  accent. Choosing Scan sends `tabTapped(.scan)`, which presents the camera and leaves the selection where it was.
  The bar, its glass and its safe area are the system's. `TegolaTabBar`, `TabBarItem` and the three tab-bar metrics
  are removed. Activity's badge (T7.7) will be the system's `.badge`.
- **`TegolaAction`** (`TegolaDesignSystem/Actions.swift`) defines every tab and every verb more than one screen uses,
  once: its words (in the design system's catalog, so translated once), its SF Symbol and its usual look. The tabs'
  items, `ModalBar`'s Close, Cancel and Save, and the shared buttons all read it. **`ActionButton(.save, id:)`** is the
  button for one, and a screen may ask for another look. A verb only one screen says stays with that screen.
- `ModalBar` takes no labels: it says Close, or Cancel when it has a Save.
- UI tests find tabs by their label in the system tab bar (`app.tab("Find")`), since a `Tab`'s identifier doesn't
  reach the system's button.
- The catalog's *tabBar* section is now *actions*: every action's item and button.

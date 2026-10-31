# Decisions

A running log. Each entry records what was asked, what was chosen, why, and what
the rejected option would have cost — that last part is the one worth having in
six months, when someone asks why a stamp cannot be lent.

Newest entries go at the bottom. `TODO.md` holds what is still open.

---

## 2026-08-20 · Part A, the product decisions

### D1 · YAML seeds, the database owns

**Decided.** A type file in `CollectionCatalog/Resources/Types/` is read once,
when the first collection of that type is created, and copied into SQLite. From
then on the database is the truth. Nothing is ever written back to a file.

**Why.** It keeps both authoring surfaces that already exist — the files stay
hand-editable and diffable in git, and the in-app field editor stays meaningful —
without either one having to win, and without a two-way sync problem.

**Rejected.** *YAML as the live truth, user-editable in Files* — a type becomes a
shareable document, but you own a parser, a validator and an error UI for
hand-broken files, and the in-app editor degrades into a text editor.
*Database only, no YAML* — simplest, but a new collection type then requires an
app release.

### D2 · Fields belong to the type, not the collection

**Decided.** A Vinyl type row owns the field set; collections reference it. Two
Vinyl collections share one field set, so adding "Last cleaned" to one adds it to
both.

**Why.** It is what the design always said: `CollectionFieldsScreen` is titled
"What a **Vinyl** knows about itself", keyed off `typeName`, not the collection.
Editing fields in one place and having them apply everywhere is the behaviour
that screen already promises.

**Rejected.** *Collection owns its fields* — no cross-collection surprises, and
"Dad's Vinyls" can stay simple, but per-collection drift means the same type
renders differently in two places and there is no one place to fix a field.

**Consequences.** Per-collection field tweaks need an override layer if they are
ever wanted. Nothing needs it today.

### D3 · A fixed spine with per-type labels

**Decided.** `title`, `subtitle`, `year`, `acquired`, `paid`, `value` and
`condition` are real columns the user cannot delete. The YAML only relabels them:
`subtitle` is "Artist" for vinyl, "Brand" for sneakers, "Country" for coins.
Everything else is a type field.

**Why.** The shelf, stats, lending log and all three sell screens read the spine
directly. Typed columns keep them fast and simple, and a user cannot break the
app from the field editor. Relabelling costs nothing and stops a sneaker sheet
from saying "Artist: Nike".

**Rejected.** *Minimal spine, everything else a field* — maximum per-type freedom,
but the shelf and stats then query dynamic keys by convention and a type that
omits "price" quietly breaks the value banner. *Fat spine, fixed labels* — dead
simple, but the app reads as a record app wearing a costume.

### D4 · Twelve types ship for the trial

**Decided.** vinyl, board games, retro games, books, sneakers, coins, stamps,
comics, LEGO, trading cards, watches, action figures. Culled before release, once
real use says which ones matter.

**Why.** A type is now one file, so breadth is cheap and the trial is what decides
the answer rather than a guess made in advance.

**Consequences.** Only five can scan a barcode into a real match — vinyl, retro
games, comics, books (ISBN), LEGO (set number). Board games have a barcode but
BoardGameGeek has no barcode index, so it is search-by-name. Coins, stamps,
cards, watches, sneakers and action figures have no usable identifier at all.
**The manual path is the majority case, not the edge case**, which is what forced
D12.

### D5 · Duplicates are a per-type mode

**Decided.** `duplicates: rows` for the nine hobbies where every copy has its own
condition and history; `duplicates: quantity` for coins, stamps and trading
cards, where a duplicate is a count. Settled properly by user testing.

**Why.** These hobbies genuinely differ, and forcing either model on both is
wrong in one direction or the other.

**The collision is smaller than it looks.** You do not lend a single stamp or sell
one out of a run, so a `quantity` type is simply not eligible for the lending log
or the sell screens. That removes the hard case rather than building both models
through it. A user who grades one specific coin promotes it to its own item.

**Rejected.** *Rows always* — matches every existing screen, but a stamp collector
recording a sheet of fifty faces fifty taps. *Quantity always* — fast for bulk,
but condition, price and lending are per-copy in reality and the lending log has
no single object to point at.

### D6 · Presets never auto-change a user's type

**Decided.** Once a type exists in the database the app never silently edits it.
The type editor offers a "3 new fields — review" row instead.

**Why.** Keeps the local-first promise, and stops a field someone deliberately
deleted from reappearing on every update. Testers can still pull improvements
deliberately, which is what matters during the trial.

**Rejected.** *Silent additive merge* — testers always run the latest thinking,
but it needs tombstones per user or their deletions undo themselves. *Never, full
stop* — zero migration code, but testers freeze on whatever shipped the day they
installed.

### D7 · The mark stays the hero; an SF Symbol does small sizes

**Decided.** "33⅓", "D20", "16BIT" set at 34pt over halftone stays the tile
identity. An SF Symbol — heavy weight, ink-coloured, over the gradient, never
raw — carries search results, lending rows, pickers and widgets.

**Why.** The mark is the house style and reads beautifully large, but turns to
mush at 16pt. Symbols cover every hobby that will ever be added, at no drawing
cost, which is what keeps *adding a type is one YAML file* true.

**Rejected.** *A custom-drawn icon set* — the best-looking and most ownable answer,
and what would make the part F family feel designed rather than assembled, but
every future type then needs a drawing before it can ship and the author becomes
the bottleneck on their own extensibility. Worth revisiting once the twelve are
culled to a stable set.

### D8 · The gradient is a type default the collection may override

**Decided.** The YAML gradient is what you get for free; the colour picker already
in the creation flow still works. The icon does not move. The palette stays at
six accents — twelve types disambiguate by ordered pairs.

**Why.** Recognition survives recolouring because the icon is fixed. Six chosen
colours are a design language; twelve are a swatch library, and part F hands this
palette to a playlist app and a link-sharing app with no use for a sneaker colour.

### D9 · The add flow assumes, shows, and lets you change the target

**Decided.** Default to the last-used collection. `ScanScreen` already draws
`ADD TO · MY VINYLS` — it becomes a control, so the target can be corrected
before the phone is raised rather than after the scan.

**Why.** People add in runs, so the assumption is right almost every time and
costs no taps. Making the existing label tappable is nearly free.

### D10 · Fan out to other providers only on a miss

**Decided.** Query the assumed type's provider first. Only if it misses, query the
others and switch type. ISBN prefixes (978/979) short-circuit to books.

**Why.** Full fan-out on every scan is twelve calls against rate-limited free
APIs, slower on bad connections, and still needs a chooser for ambiguity — so the
fallback has to exist either way. Build the fallback, not the fan-out.

### D11 · Review by default, crate mode to opt out

**Decided.** Single adds keep "check every field before saving". A deliberate
crate mode keeps the camera open, saves confident matches immediately with an
UNVERIFIED sticker, and queues them for later review.

**Why.** Onboarding a 482-object shelf and adding tonight's find are different
jobs. Always-review makes the first hour — the hour that decides whether someone
stays — into 482 confirmation taps. Always-save reverses a stated principle and
lets low-confidence matches become the catalogue.

**Rejected.** *Always review* — one path, fully trustworthy data, but the opposite
of the stated goal. *Always save with undo* — fewest taps, but silently contradicts
"nothing saves silently".

### D12 · Photo-first for the seven types with no identifier

**Decided.** For sneakers, coins, stamps, cards, watches and figures the shutter
*is* the add button. The photo becomes the item immediately in a "needs details"
state and you keep shooting.

**Why.** Fewest possible taps, pairs exactly with crate mode, and matches how
people want to start: get everything in, tidy later. A photo is also the single
most valuable thing in a collection app.

**Rejected.** *Straight to the form* — honest and cheap, but half the app becomes a
spreadsheet while the other half feels magic.

### D13 · Enrichment is asynchronous and never destructive

**Decided.** Image recognition runs as a webservice and answers late, sometimes
much later. When it does: notify, fill **only fields that are still empty**, and
ask the user to confirm. It may never overwrite something a person typed.

**Why.** Late, occasional, imperfect enrichment is genuinely useful and genuinely
untrustworthy. Filling only the gaps makes a wrong answer harmless, and asking
keeps the "you own the record" principle intact even when the app is guessing.

### D14 · The item detail screen is a display case

**Decided.** The detail screen is presentational. Its only controls are actions —
lend, sell, add photo — plus one Edit that opens a full form with Save and
Cancel. Disc colour moves there, along with every other editable value.

**Why.** It makes the object feel like an object rather than a row in a database,
and Cancel means a mistyped value is never saved. Editing is rare next to adding,
so the extra taps land where they cost least.

**Worth knowing.** The swatch row is `@State private var material` today — it is
never persisted. It is currently a toy for viewing a record in five pressings,
not an editor. Moving it also means making it mean something.

**Rejected.** *Inline tap-to-edit with autosave* — fewest taps and consistent with
the app's thesis, but the display case becomes a form, every field becomes a tap
target, and accidental edits have no Cancel.

### D15 · Dated actions are logged events, displayed as the latest

**Decided.** A new `event` field type. Cleaned, serviced, read, built, inspected
are repeatable actions written to the item's timeline; the detail row shows only
the most recent. A plain `date` stays a *fact* about the object — a sneaker's
release date, a car's first registration — while an `event` is something *you did*.

**Why.** "Only the last cleaning matters" is about display; "a service chart would
be interesting" is about storage. Logging underneath and showing the latest
satisfies both with one mechanism, so a car's service chart needs a chart and not
a new storage shape. `TimelineEntry` and the History tab already exist.

**Rejected.** *Per-field `log: true`* — most precise about intent, but two storage
shapes, two editors and two renderings, and every new type file would ask you to
predict which dates someone will one day want a chart of.

### D16 · Cars and motorbikes join as types 13 and 14

**Decided.** Both were in the original list and both decode their VIN through
NHTSA vPIC, which is free and needs no key.

**Why.** A vehicle is the strongest case for D15 — service and roadworthiness
history is most of what its value rests on — and it pressure-tests the model with
an object worth more than every other collection combined.

### D17 · Labels translate; terms of art never do

**Decided.** Two classes of string, marked in the type files. Field labels,
section titles and help text are translated. Grading codes and format names —
MNH, VG+, CIB, MISB, MS-70, PSA, 2×LP — stay fixed in every language.

**Why.** That is what collectors type, search and trade in. A French philatelist
writes MNH. Translating them would invent vocabulary nobody uses, break search for
the people who know the hobby best, and require every translator to be a subject
expert in fourteen collecting fields.

**Consequences.** This is the unblocker for C3 — it says exactly what goes in the
string catalogue and what does not.

### D18 · Search matches everything; `searchable` only ranks

**Decided.** FTS5 indexes every field, every note and the collection name. The
per-type `searchable` list stops being a filter and becomes the ranking and the
result subtitle. One global field on the shelf; inside a collection the same
field scopes to that collection.

**Why.** "Steel Wool" is printed on the detail sheet but is not in the searchable
list — typing a word you can literally see and getting nothing is the one
unforgivable search failure, and the user cannot tell a missing record from an
unindexed one. Matching everything is nearly free with FTS5.

### D19 · `lastCleaned` — superseded

Recorded then reversed within the same session: it was briefly settled as a plain
date with history parked for later, before D15 replaced it with one mechanism for
all dated actions. Kept here because the reasoning that overturned it — display
versus storage — is the useful part.

### D20 · List entries are structured, declared per field

**Decided.** A `list` field declares the shape of one entry in the type file:
a tracklist is position/title/duration, a restoration log is date/what/cost, an
accessory is just a name.

**Why.** Discogs already returns a tracklist structured, so flattening it to
strings throws data away. It buys the match subtitle ("Track 4 · The Bird"), a
sortable tracklist and a total runtime — and clean track titles, which is exactly
what E1 needs to match a record to Apple Music or Spotify.

**Rejected.** *Plain strings* — nothing to build, search still finds the track, but
position cannot be separated for display and a future MusicKit match would have
to parse titles back out of display strings. *Strings now, structure later* — the
migration would arrive after real user data existed in the loose shape.

### D21 · Search matches list elements, not just fields

**Decided.** The FTS index is flattened to one row per `(item, field, ordinal,
text)`, so a single track on an LP is its own searchable unit. Results name the
match reason in the subtitle, from `snippet()`.

**Why.** "Find the LP with 'The Bird' on it" is a real thing collectors want, and
a field-level index cannot answer it. It generalises for free to every list field
in the files: expansions, accessories, modifications, restoration, missing parts.

**Amends D18.** `searchable` stays the **reference** — the authoritative per-type
config, extended in the YAML whenever a type needs more. Vinyl's now includes
`tracklist` and `label`.

### D22 · The match screen answers "do I already own this?"

**Decided.** Every scan's match screen also reports, unprompted: an exact-barcode
"you already own this", and related items drawn from a new `related:` key in each
type file. Tappable rows straight to those items.

**Why.** It is the record-shop question, and it needs no new mode: you scan and
simply do not tap Add. It is also the same question asked at home, where it
prevents accidental duplicates.

**Rejected.** *A third "Check" scan mode* — a big glanceable answer optimised for a
shop, but a third mode on a screen that already has two, chosen before the useful
moment. Worth revisiting if shop-scanning becomes a habit, as a sticky mode layered
on top of the always-on answer.

**What "related" means is per type.** vinyl: artist + label. comics: series +
writer + publisher. lego: theme. cars and motos: make. All fourteen files carry
it, and every key resolves against that type's spine or fields.

### D23 · Local-first; sync is opt-in

**Decided.** The app is fully usable with no account, forever — SQLite on device,
nothing phones home. Sync is a deliberate switch that adds a second device, and
turning it off leaves the local database untouched.

**Why.** It resolves the collision head-on rather than quietly dropping a stated
principle: sync becomes a feature you choose, not a substrate you depend on.
SQLiteData's `SyncEngine` is built for this shape.

**Rejected.** *On by default when signed into iCloud* — it just works, and loses the
least data to lost phones, but it makes the account load-bearing and puts a
private catalogue in the cloud without anyone asking for that. *No sync, export
only* — honours the principle absolutely, but losing a phone loses weeks of work.

**Consequences for C1.** Stable ids, soft deletes and conflict-tolerant columns
are schema decisions and have to be made *as* C1 lands. Retrofitting them is the
expensive version.

### D24 · A share is an image card plus a deep link

**Decided.** Sharing produces a card rendered in the house style — sleeve, title,
pressing, condition — with a deep link alongside it. Anyone can see the image;
anyone with the app can tap through.

**Why.** The image needs no account, no server and no app on the other end, and it
carries the aesthetic outward. The link turns a share into a growth loop instead
of a dead end.

### D25 · Two share payloads, chosen at share time

**Decided.** *Share the record* carries the object's identity — barcode or provider
id plus public facts — and opens in Tom's app as a read-only card with one tap to
add it to his own collection. *Share my copy* carries my row: my pressing, my
condition, my photos.

**Why.** They are genuinely different acts. "Look at this record" is about the
object and should cost nothing; "look at *mine*" is about the copy I am proud of
and is worth the extra machinery.

**The privacy rule.** The spine includes `paid`. *Share my copy* must filter it by
default rather than by accident, and the share sheet has to say what it is about
to reveal. This is a default, not a warning to be dismissed.

**Consequence.** *Share my copy* needs the record to be fetchable, so it depends on
the same iCloud account D23 made optional. With sync off, sharing degrades to the
image card — which is the correct degradation, not a missing feature.

### D26 · Search tokens, not a query grammar

**Decided.** `.searchable(text:tokens:)` with suggested tokens built from each
type's YAML — type names, spine roles, statuses, condition values. The user picks
`Watches` and `Bought 2013`; free text falls through to FTS. Debounce with
`.task(id:)` plus `Task.sleep`.

**Why.** The platform already solves this at a lower rung than a parser. Picking a
token cannot be misinterpreted, so there is no grammar to write, no ambiguity to
resolve, and no interpretation to explain back to the user. A model-based parser
would have had to emit these same filters anyway.

**Rejected.** *A hand-written token grammar* — deterministic and offline, but it is
a parser per language for a problem selection removes. *An on-device model* — reads
anything, but needs a far newer deployment target and still needs the structured
filters underneath.

**Two things deliberately not built.**

*Runtime translation of token labels.* Labels are known at build time and already
belong in the string catalogue for C3. Apple's Translation framework would add an
asset-downloading async API to produce worse translations of chrome. Reserve it
for user **content** — a Japanese Discogs title, a note in another language.

*A minimum query length.* `U2`, `XO`, `IV`, `Q`, `IT`, `8½`. Two-character
searches are real in these hobbies, and a minimum is a rule whose only output is
bugs. Debouncing already covers the performance worry it was meant to solve.

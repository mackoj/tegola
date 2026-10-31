# Collection types

One file per type. These are **seed data**: they are read once, when a collection
of that type is first created, and copied into the database. From that moment the
database is the truth and the user's edits live there — a file is never written
at runtime, so it stays hand-editable and diffable in git.

Fields live on the **type**, not on the collection: two Vinyl collections share
one field set, which is why `CollectionFieldsScreen` is titled "What a *Vinyl*
knows about itself".

## Schema

```yaml
id:            vinyl                    # stable, kebab-case, never changes
name:
  singular:    Record                   # "1 Record"
  plural:      Records                  # "128 Records"
  collection:  My Vinyls                # default name offered at creation
mark:          "33⅓"                    # the stamp on the shelf tile
icon:          opticaldisc              # see "Icons" below
gradient:      [teal, cobalt]           # two Palette keys
duplicates:    rows                     # rows | quantity, see below

spine:                                  # relabels the fixed columns; the roles
  title:       Album                    # themselves are the same for every type
  subtitle:    Artist                   # and cannot be deleted by the user
  year:        Year
  acquired:    Acquired on
  paid:        Paid
  value:       Value

conditions:    [Mint, Near Mint, …]     # this type's grading scale, best first

lookup:
  identifier:  barcode                  # barcode | isbn | setNumber | none
  symbologies: [ean13, upc-a]           # what the camera should look for
  providers:   [discogs, musicbrainz]   # tried in order; [] means manual only

searchable:    [title, subtitle, year]  # what a search matches, in order

fields:                                 # on top of the spine
  - key:     format                     # stable; the column/JSON key
    label:   Format                     # shown to the user, translatable
    type:    choice                     # see "Field types"
    options: [LP, 2×LP]                 # choice only
    unit:    mm                         # number only, optional
    sample:  2×LP                       # the "e.g." in the field editor
    auto:    true                       # can a lookup fill this? (the AUTO badge)
```

## Field types

`text` · `number` · `yesNo` · `list` · `date` · `photo` · `link` · `money` are
the eight `FieldType` cases that already exist in `Models.swift`.

Writing these files surfaced two gaps in that enum:

- **`choice`** — a fixed set of options. Every type here needs it (condition
  scales, formats, regions, grading services). Today the vinyl preset fakes it
  with `text` and the sample "Coke-bottle clear", which is why disc colour is
  free text that cannot be validated or translated.
- **`unit` on `number`** — sneaker size, case diameter in mm, coin weight in g,
  play time in minutes. Without it the unit ends up inside the value as text and
  stops being sortable.
- **`event`** — a dated action the owner performed, and may perform again:
  cleaned, serviced, read, built, inspected. Always logged to the item's
  timeline; the detail row shows only the most recent, so it reads as
  "Last cleaned · 3 Feb 2026" while the history stays underneath for a chart.
  A plain `date` is a *fact* about the object (a sneaker's release date, first
  registration); an `event` is something *you did*.
- **`entry` on `list`** — the shape of one entry, so a tracklist keeps position,
  title and duration apart instead of flattening to a display string. Most lists
  are a bare `[name]`; a tracklist and a restoration log are not.

Both are used below on the assumption they will be added.

## Icons

The names are SF Symbols, chosen as placeholders. The house style is a hand-drawn
zine, so system symbols may read as foreign next to it — A2 decides whether these
resolve to SF Symbols or to custom assets. The key stays either way.

## Duplicates

`duplicates: rows` — every copy is its own item, with its own condition, price
paid, value, photos and lending state. Nine of the twelve types work this way,
and it is what the rest of the app already assumes: you lend *an item*, you sell
*an item*, you grade *an item*.

`duplicates: quantity` — one item carries a count. Coins, stamps and trading
cards only: these are bulk hobbies where a duplicate is a number, not a new
object, and nobody wants fifty taps to record a sheet of stamps.

The two modes collide less than they look. You do not lend a single stamp, and
you do not sell one out of a run — so a `quantity` type is simply not eligible
for the lending log or the sell screens, which removes the hard case instead of
forcing both models through it. A user who *does* grade one specific coin
promotes it: adding that graded copy as its own item is always allowed.

Which types sit on which side is a guess to be settled by user testing, not a
law. Changing a type's mode is a one-word edit here plus a migration.

## Related

`related:` names the keys that answer *"do I already own something like this?"*
when you scan in a shop. It differs by hobby: another record by the artist or on
the label, another issue in the series, another set in the theme, another car by
the make. The match screen shows them unprompted, so checking costs nothing and
needs no separate mode.

## Searchable

`searchable:` is the reference list — the authoritative per-type config, extended
here whenever a type needs more. It drives ranking and the result subtitle, not
what is matched: the index covers every field, and `list` fields are flattened to
one row per entry, so a single track on an LP is its own searchable unit.

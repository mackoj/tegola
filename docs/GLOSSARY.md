# Tegola: glossary

The words collectors read, ported from clctn's `CONTEXT.md` (the product's vocabulary is unchanged; only the name is
Tegola's, PLAN §10 answer 2). Code, copy and tests use these words and avoid the ones marked _Avoid_. Terms for
things not in v1 (the offer index, Founding Cataloguer, the type board) stay, so later milestones speak the same
language.


A private catalogue for people who own things on purpose. It answers four questions about every object a collector owns: what is it, where is it, who has it, and what happened to it.

## People

**Collector**:
The person whose shelf it is. Always the owner of the catalogue on their device.
_Avoid_: User, customer, account

**Hardcore / Hobbyist / Owner**:
The three audiences the product is designed for. The Hardcore has 400+ objects and knows the grading scale. The Hobbyist has 60–150 and lends to friends. The Owner has one inherited collection and will never learn a scale. The app never asks which one you are.
_Avoid_: Power user, casual user

**Person**:
Someone the collector lends to or borrows from, created by typing their name. They have a page showing what they hold and their track record. A Person is not required to have the app.
_Avoid_: Contact, friend, borrower (as an entity)

**Account**:
The display name and contact a collector needs only to deal in the offer index. Nothing else in Tegola uses one; the Apple identity covers everything else.
_Avoid_: Profile (that is the onboarding question), login

**Founding Cataloguer**:
A member of the first cohort (≈50) who helped write a type's fields. They are credited by name and keep the founding price for good.

## The shelf

**Object**:
One physical thing a collector owns, wants, or holds for someone else. It is the unit of everything.
_Avoid_: Item, product, entry, SKU

**Shelf**:
Everything a collector owns, across all collections. Also the name of the first tab.
_Avoid_: Library, inventory, database

**Collection**:
A named group of objects, e.g. "My Vinyls". Usually has one type. A **Mixed collection** has none, and each object carries its own type.
_Avoid_: Folder, list, category

**Run** / **Set**:
A group of objects a collector's hobby already treats as belonging together —
a Blue Note 4000 run, a stamp series, a numbered edition, or one the collector
made themselves ("the ones Dad gave me"). A **gap** is a place in a run where
something is missing; a gap the collector wants becomes a wanted object. How
many are in a run is the collector's fact, never the app's: it says "12 owned"
rather than inventing "12 of 20".
_Avoid_: Series (as the product word — it is a field on a type), completion
percentage, collection (that is the named group)

**Wanted object**:
An object the collector does not own yet: the same type and fields, with the owned flag off. It is drawn with a dashed edge and never counts in value, insurance or stats.
_Avoid_: Wishlist item

**Wishlist**:
A collection of wanted objects, each with a priority and optionally a price cap. It lives inside Shelf. The hunt.

**Grail**:
A wanted or owned object the collector has marked as most important to them.

**Borrowed object**:
An object on the collector's shelf that belongs to someone else. It is shown with a dashed edge and never counted.

**Not yours**:
The single visual rule for wanted, borrowed and other people's objects: a dashed edge and no drop shadow, at every size.

**Place**:
A physical location that holds objects of any type, created by typing its name on an object and nested with a separator, e.g. "Cellar › Rack 3 › Bin 12". Each type names it in its own words (crate, bin, box).
_Avoid_: Location field, storage, shelf (as a location)

**Unplaced**:
The normal state of an object with no place. It is never a warning.

## Types

**Type**:
The definition of one kind of collectible. It sets the object's nouns, spine labels, fields, condition scale, bulk rule, lookup strategy and signatures. The app owns the verbs; the type owns the nouns.
_Avoid_: Category, template, schema (in product talk)

**Official type**:
A type shipped and maintained by Tegola, with a real scale and, where possible, a lookup source and a 3D object.

**Custom type**:
A type a collector builds on their device, field by field. It works immediately and is private until published.

**Community type**:
A custom type another collector published to the type board and that others download and use. It is credited and has a dashed edge.

**Music**:
The single type for recorded music on any physical format. Its object is a **Release**. Each format (vinyl, CD, cassette, other) is a **Subtype**, which narrows the formats and adds its own fields (D-35).
_Avoid_: Vinyl type, CD type, Records (as the type name)

**Vehicles**:
The single type for cars and motorbikes, which are its two subtypes.

**Thing**:
The generic type that accepts anything. Only a name is required. It has no scale and no signature, and it is the route toward a real type.
_Avoid_: Other, misc, generic item

**Type board**:
The public place where custom types are published, downloaded, adopted and proposed for becoming official. It carries types, never objects.

**Type proposal**:
A published custom type on its way to becoming an official type: Proposed → Gathering → Drafting → Shipped. It sends the shape, never the shelf.

**Subtype**:
One level below a type, keyed on platform for games and format for music and film: a Saturn game, a vinyl release, a Blu-ray. It inherits everything and can only add nouns: fields of its own, a preset or hidden field, a narrowed choice, the parts its set counts, clocks from the library. It can't remove or rename a parent field, and has no subtypes of its own (page 48).
_Avoid_: Platform type, format type, variant

**Item level**:
The fields every type inherits because they mean the same everywhere: who **Signed** it (by, dedication, date, proof) and what it's a **Bundle of** (the works inside; two or more makes a bundle). They stay hidden until the object has a value, and "+ Add" reveals them.
_Avoid_: Common fields, base type

**Migration**:
Moving a collection from one type to another, e.g. custom → official or Thing → a real type. It is offered, never imposed, loses no value, and can be undone for 30 days.

**Spine**:
The two or three facts that identify an object in a row (title, subtitle, year), plus acquired, paid and value, each relabelled by the type (Album / Artist / Year; Wine / Appellation / Vintage).

**Field**:
A typed fact about an object beyond the spine. Its **kind** (number, choice, scale, date, log, …) decides the control, sorting and search.

**Condition scale**:
A type's own ordered grading vocabulary, best first (Goldmine, Sheldon, fill level). It is never converted to another type's scale.
_Avoid_: Rating, score

**Axis**:
A second or third thing graded on the same scale (sleeve; box and manual). There are three at most.

**Bulk rule**:
Whether a duplicate is a new object (**rows**) or a count on one object (**quantity**). Quantity objects cannot be lent or sold one at a time.

**Promote**:
Pulling one specific copy out of a quantity object so it becomes its own object with its own grade and history.

**Consumable**:
A quantity type whose count goes down through use (wine). Consumption is logged and never deletes the object.

**Part**:
An object attached to exactly one parent object (a monitor on a computer). One level only. Its value counts once.

**Signature**:
A small, type-specific drawing of a field the type already owns (grade ladder, maturity gauge, the case of bottles). It appears only on the object screen and never collects data.

**Status**:
One chip per object, drawn from five shared swatches: fine · good · watch · act · gone.

**Clock**:
A type's one derived, time-based status (drinking window, service risk, light exposure). Always labelled **Estimate**, opt-in to notify.
_Avoid_: Timer, reminder, alert

**Today strip**:
The lines at the top of Shelf that appear only when non-empty: to tidy, need attention, overdue.

**Needs attention**:
The only cross-type number: objects whose status is watch or act.

**Type verb**:
The single action a type may add to the app's verbs (Open a bottle, Add part).

## Adding

**Capture**:
Adding objects with the camera: photo first, barcode second, typing last.

**Sweep**:
Continuous capture of many objects in one session. The camera stays open, confident matches land unconfirmed, the rest queue.
_Avoid_: Crate mode, rapid mode, batch scan

**Lookup**:
Asking an outside source what a captured object is, from a barcode or printed text. It happens automatically and sends no photo.
_Avoid_: Scan credit

**Identify**:
Sending one photo out to find a match. It happens only per shot when the collector taps "Identify?", or always if they turn that on. This is the only moment a photo leaves the phone.

**Unconfirmed**:
An object whose identity was guessed and not yet agreed by the collector.
_Avoid_: Unverified, draft

**Needs details**:
An object saved from a photo with nothing identified yet.

**Review queue**:
Everything guessed or incomplete, waiting for the collector to agree. Nothing is confirmed on their behalf.

**Enrichment**:
A late lookup answer that offers to fill only empty fields and never overwrites anything typed.

**Import**:
Bringing an existing list in from Discogs, another app or a spreadsheet. It only adds, never merges or invents, and can be undone as a batch for 30 days.

## Life of an object

**History**:
The append-only story of an object: added, acquired, lent, returned, serviced, regraded, sold. Nothing overwrites.

**Added** is the day the record was made; **acquired** is the day the collector got the thing. They are rarely the same day and the app only ever witnesses the first, so it never writes the second on the collector's behalf.

**Loan**:
An object lent to a Person, with a due date and an optional note. It opens and closes by **Handshake**. If the Person never confirms, it stays **unconfirmed**.
_Avoid_: Lend (as a noun), checkout

**Loan link**:
The link a borrower receives. It opens in a browser, with no app and no account, to confirm "I have it" and later "I gave it back".

**Handshake**:
Both sides confirming a social act (hand-off, return, offer, reservation), so an object's state never changes because someone else tapped something.

**Reservation**:
A queued loan from someone else's shelf. Sketched, not built.

**Let go**:
Taking an object off the shelf for good, with a reason: sold, gifted, traded, lost or broken. It stays in the **archive** and still answers "did I ever own this?"
_Avoid_: Delete, remove

**Sold**:
The "Let go" reason for an object that was sold. With money on, it keeps what it fetched.

**Co-owned shelf**:
A collection two people both see, where every object still belongs to exactly one of them.

## Sharing

**Share the record**:
Sending an object's public identity. It opens as a read-only card the receiver can add to their own shelf.

**Share my copy**:
Sending the collector's own copy (condition, photos, optional asking price). What they paid is never shared.

**Share card**:
The rendered image-plus-link a share produces. It works with no app and no account.

**Nudge**:
Either the collector's one-tap re-send of a loan link to an overdue borrower, or an app notification that names one specific unfinished thing.

## Money

**Money switch**:
The single setting that shows or hides every value, market line and sell action. With it off, no screen loses its meaning.
_Avoid_: Selling mode, pro mode

**Value**:
What an object is worth according to a named source and date. The collector's own figure always wins on their screen.

**Price receipt**:
The source, sample size and date behind any value. When there is no source, nothing is shown.

**Might let go**:
A private flag on an owned object meaning the collector would consider parting with it. It works with money off. It is evidence of supply before any market exists.
_Avoid_: For sale, spare, trade bait

**Offer**:
An object its owner marked available at an asking price. Only offers leave the phone, never the shelf.

**Offer index**:
The public search over offers. Objects enter when marked available and leave the moment they are not.
_Avoid_: Marketplace, store

**Disposal sheet**:
One act offering several objects, across types, at once.

**Inventory document**:
A dated document listing every object with photo, condition, provenance, place and price paid. It is an owner's inventory, not an appraisal. With money on it becomes the **insurance export**, adding market values and their basis.

## Paying

**Free tier**:
What a collector can do without paying. The boundary is not fixed yet; the working hypothesis is one collection of up to fifty objects with every feature. It is always a cap on adding, never on keeping.

**Unlock**:
The one-time purchase that removes the free tier's limits.
_Avoid_: Pro, premium, subscription

**Founding price**:
The launch rung of a published, rising price ladder. Kept forever by whoever paid it.

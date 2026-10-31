# Decisions

## D27 — Wishlists are collections, not a separate feature
A wanted object is an ordinary object with an `owned: false` flag: same type, same fields, same history. The day it arrives you flip the flag and it's on the shelf with its provenance intact. Consequences: wishlist objects never enter value, insurance or stats; they carry two extra fields (priority, price cap) and drop condition-of-yours.

**Visual rule:** not-yours = dashed 2.5px edge + no drop shadow, at every size. Owned = solid edge + 4px offset shadow. One rule, no new colour.

## D28 — Shareable wishlist reveals wants, never holdings
A shared wishlist link is readable with no account. The recipient's own shelf is matched against it locally-in-spirit: they see "you own 3 of these". The owner of the list learns nothing until the recipient taps to point at one object. Pointing is always a separate, explicit tap.

## D29 — For-sale search is an index of offers, not of shelves
Infrastructure implication, accepted: an object enters the public index when its owner marks it available and leaves the moment they don't. No shelf is ever mirrored server-side for search. This is the app's first piece of shared infrastructure and is hard to withdraw once people search it — flagged for the user's call.

## D30 — Wishlist hits fire on the full match only
Print + grade + price cap together. Near misses stay silent, or the alert becomes noise and gets muted within a week.

## D31 — Reservation = a queued lend (sketched, not built)
Future library case (books, CDs, games). Reuses the existing lend handshake and due date; adds only a waiting queue. Only people the owner already shares that shelf with can reserve; a public library would need its own setting and its own screen. The owner can cancel any reservation without a reason.

**Open:** does a wishlist live inside the Shelf tab as a flagged collection (as built, keeps the bar at five), or become its own destination?

# Shelved

## S1 — Photo vs. render as an object's shelf image
**Status:** shelved, awaiting user feedback. Do not build.

Today the same gradient block does three jobs: stand-in for a specific cover we lack art for (list rows, marketplace card, handshake cards), generic swarm of many objects (value strips, `+15`), and authored surface where the gradient *is* the art (3D vinyl box faces). Only the first is a problem.

Direction if it comes back:
- Image appears where the object is **named** (thumb + title); design language where it's **counted** (8+ at once, empty states, viewfinders, the 3D box).
- On add, the user picks the default render — his photo or ours.
- Open sub-question, unresolved: scope of that choice (per object / per collection / both layered), and what shows when the default is "clean render" but no catalogue match exists — his photo anyway, or a typographic card.

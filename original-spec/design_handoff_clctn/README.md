# Handoff: CLCTN — collection app (iOS)

## Overview

CLCTN is an iPhone app for people who own a lot of objects: vinyl, board games, figurines, coins, watches, comics, trading cards and ten more types. It answers four questions — *what do I own, who has it right now, what is it worth, what does it look like* — and adds a marketplace backbone later, in gated phases.

This bundle contains every design artifact produced so far: the interactive prototype (45 screens), the design-system reference, and seven planning documents (brief, business plan, revenue model, growth plan, video playbook, event taxonomy, master plan) plus the running decision log.

## About the design files

**The files in `design/` are design references created in HTML.** They are prototypes showing intended look and behaviour — they are not production code and should not be ported, transpiled or embedded.

The target codebase for this work is **`mackoj/the-collection`, branch `main`** — a Swift/SwiftUI iOS app (see `design/github.md` for the screen→source map from the last sync, 2026-08-20). The task is to **recreate these designs in that codebase**, using its existing packages, screens and patterns (`Packages/Sources/*Screen/`, `CollectionCatalog/Resources/Types/*.yml`, `CollectorKit/`). Where the repo already has a screen listed in the screen map below, extend it rather than starting over.

If you are implementing outside that repo, SwiftUI on iOS 17+ is the intended platform; the design assumes native navigation, sheets, camera and LiDAR.

### How to view the prototype

- `design/CLCTN App.html` — **open this first.** Self-contained, works offline, no server. It renders the app inside an iPhone frame.
- `design/Collections App.dc.html` — the source of that prototype. Needs `support.js` and `ios-frame.jsx` alongside it (both included). The screen shown is driven by the `screen` prop, whose enum lists all 45 screens.
- The remaining `.dc.html` files are strategy documents, not UI. Read them as written specs.

## Fidelity

**High-fidelity.** Colours, typography, spacing, borders, shadows and copy are final and deliberate. The visual language is a hard-edged, high-contrast "printed object" style — 2.5px black borders, offset hard shadows, no blur, no gradient chrome. Reproduce it precisely; it is the product's differentiator, not decoration.

Two things are explicitly *not* final and are marked as such in `design/decisions.md`:
- **S1 — photo vs. render as an object's shelf image.** The prototype uses gradient blocks as stand-ins. Shelved awaiting user feedback. Do not build a photo/render toggle yet.
- **Wishlist placement** — inside the Shelf tab as a flagged collection (as built) vs. its own destination. Build as prototyped.

---

## Design tokens

### Colour

| Token | Hex | Use |
|---|---|---|
| Ink | `#17130F` | All borders, all shadows, primary text, dark screens' background |
| Ink soft | `#241F19` | Inner rings on dark surfaces (e.g. record label) |
| Paper | `#F3ECE0` | Default screen background, text on dark |
| Paper warm | `#EDE4D6` | Second surface (received/shared views, inset tracks) |
| Paper deep | `#DDD2C0` | Sticky headers on warm screens |
| Card | `#FFFFFF` | Raised cards on paper |
| Muted | `#6E6458` | Secondary body text |
| Meta | `#8A7F70` | Mono eyebrow labels, tertiary text |
| Rule | `#C9BFB0` | Inert tracks, sheet grabber |
| Rule dark | `#B9AC99` | Dashed borders, warm-screen hairlines |
| Yellow | `#FFD24A` | Primary accent — avatars, badges, active scan mode, highlight blocks |
| Orange | `#FF5B2E` | Primary CTA, links hover, alert shadow colour |
| Pink | `#E5457B` | "Grail" marker, accent tint |
| Teal | `#12A594` | Type tint |
| Green | `#0E6E5E` | Money / market / positive delta, LiDAR badge |
| Cobalt | `#2B44D6` | Link colour, type tint |
| Rust | `#C2371F` | Negative delta, type tint |
| Camera black | `#0C0A08` | Camera and capture screens |
| Camera gradient | `linear-gradient(180deg,#2A231C,#0C0A08)` | Viewfinder backdrop |

Type-tint gradients are per collection type and live in the repo's `Resources/Types/*.yml`. Format used in the prototype: `linear-gradient(150deg, <a>, <b>)`.

### Typography

Three families, no exceptions.

| Role | Family | Spec |
|---|---|---|
| Display | **Bricolage Grotesque** 800 | Screen titles 34–36px / line-height .95–.96 / letter-spacing −.03em. Big numbers 22–28px. Type marks 20–34px at −.04em, line-height .85 |
| UI / body | **Archivo** | 400 body 13px/1.5; 600 labels & nav 12–14px; 700 titles & buttons 13–16px |
| Meta / data | **DM Mono** 500 | 9–11px, letter-spacing .10–.14em, UPPERCASE. Eyebrows, counts, spine labels, prices in tables |

Titles wrap deliberately across two lines (`My<br>Collections`, `Out of<br>the house`, `The<br>numbers`) — keep the break.

On iOS: register the two Google fonts; do not substitute SF Pro. Body text 13px in the mock maps to ~15pt; scale with Dynamic Type but hold the display face at its designed optical size.

### Spacing, radius, shadow

- Screen padding: `20px` horizontal (`18px` on dense list screens, `24px` on the empty state).
- Top inset: `58–74px` depending on whether the screen has a back row (status bar + safe area).
- Bottom inset with tab bar: `108px`. Without: `36–40px`.
- Grid/stack gaps: `5–14px`; card internal padding `10–16px`.
- Radius: `4px` (tab glyphs) · `6–8px` (chips, counters) · `11–14px` (cards, fields) · `16–18px` (large cards) · `24px 24px 0 0` (bottom sheets) · `999px` (pills, avatars, buttons).
- Border: `2.5px solid #17130F` is the default everywhere. `2px` on small chips. `2.5px dashed #B9AC99` = not-yours / add-new.
- Shadow: hard offset only — `3px 3px 0 #17130F` (cards, chips), `4px 4px 0 #17130F` (large cards), `5px 5px 0 #17130F` (documents). Never a blurred shadow. On dark surfaces the shadow colour becomes `#FF5B2E`.
- Hit targets: 44×44 minimum. The avatar button, tab items and the centre scan button are all at or above it.

### The one visual rule to never break

From decision **D27**: *not-yours = dashed 2.5px edge + no drop shadow, at every size. Owned = solid edge + 4px offset shadow.* One rule, no new colour. It applies to wishlist objects, borrowed objects, and anything in a shared list the user does not own.

---

## Screens

45 screens, all in `design/Collections App.dc.html`, selected by the `screen` prop. Set it to any value below to see that screen. Grouped as in `design/Screen Index.dc.html`.

### Core shelf
| `screen` | Name | Purpose |
|---|---|---|
| `home` | My Collections | Landing. Value + count summary cards, then a 2-up grid of collection-type tiles (mark, count, name) and a dashed "New collection type" tile. Tab bar. |
| `empty` | Empty state | First run. Illustration of stacked objects, "Nothing on the shelf yet", one orange CTA to pick a type. |
| `collection` | One collection | Title + mono meta line (`128 RECORDS · €6,410 · 2 LENT`), then object rows rendered as spines with type gradient, dot texture, and optional corner badge. |
| `item` | Object detail | **The centrepiece.** Dark screen. Interactive 3D sleeve (drag to rotate, idle auto-rotation ±, LiDAR/special-edition sparkle burst on tap), then four tabs: Overview / Details / History / Market. |
| `quantity` | Multiples | An object owned ×N (coins, cards) as one entry with a count, not N rows. |
| `search` | Search | Token/filter chips in a bordered field, results below. |
| `settings` | Settings | Money display, selling, exports, account-free posture. |
| `icons` | D7 · small sizes | Spec screen: how type marks render at 16/24/32px. Reference, not a user screen. |

### Adding objects
| `screen` | Name | Purpose |
|---|---|---|
| `scan` | Camera | Viewfinder. Mode segmented control: Barcode / Photo / Look-up-off. Identify toggle. |
| `crate` | Crate mode | Continuous capture of many objects in a row; running tally. |
| `review` | Crate review | The queue captured in crate mode, before commit. |
| `match` | Match confirm | Candidate matches from the catalogue; pick or reject. |
| `enrich` | Enrichment sheet | What the lookup filled in, and what it cost in credits. |
| `addform` | Add form | Type-specific fields (see "Type system"). |
| `edititem` | Edit object | Same fields, populated. |
| `newtype` | New collection · step 1 | Pick from 14 built-in types, 2-up grid of tinted cards. |
| `newfields` | New collection · step 2 | Confirm/adjust which fields this type gets. |
| `propose` | Propose a type | User submits an unsupported type into a queue. |
| `notype` | No matching type | Permanent no-provider case (sneakers). Manual entry only. |
| `import` | CSV import | First-hour path for people with an existing spreadsheet or Discogs export. |
| `offline` | Lookup with no network | Barcodes read and queued, titles unknown, resolved later. |
| `capture` | 3D capture | LiDAR/photogrammetry pass with progress ticks. |
| `inspect` | Inspect mode | Full-screen 3D object examination. |

### Lending
| `screen` | Name | Purpose |
|---|---|---|
| `lending` | Out of the house | Lent objects, overdue first, with borrower and due date. |
| `lendsheet` | Lend sheet | Bottom sheet: pick person, set due date, confirm. |
| `person` | One borrower | Everything that person has, and their history. |
| `return` | Return handshake | Confirmation sheet on receiving an object back. |
| `nudge` | Nudge | Reminder composition for an overdue object. |
| `borrowed` | Things that aren't yours | Objects you hold that belong to someone else. Dashed edges throughout. |
| `coshelf` | Co-owned shelf | A shelf two people own together (D23–D25). |
| `received` | Received shared object | What a recipient sees from an object link, with no account. |
| `link` | Incoming deep link | Sheet presenting over the current tab; Close, not Back. |
| `magic` | Magic link / web fallback | F4 pressure test — link opened without the app installed. |

### Value & selling
| `screen` | Name | Purpose |
|---|---|---|
| `stats` | The numbers | Two tabs: Collections / Value. Genre bars, oldest piece, streaks. |
| `insure` | Valuation export | Itemised insurance-grade export. Drives the M4 revenue meter — the insurer's required fields determine this screen. |
| `sellA` / `sellB` / `sellC` | Sell flow, three states | Mark available → price against comps → live listing (dark). |
| `sold` | Sold history | What left, to whom, for how much, vs. what was paid. |
| `market` | Marketplace search | Index of *offers*, never of shelves (D29). |
| `promote` | Promote from a pile | One coin leaves a ×12 stack and becomes its own entry. |

### Wishlists
| `screen` | Name | Purpose |
|---|---|---|
| `wishlist` | Wishlist | Wanted objects: same type, same fields, `owned: false`. Dashed edges. Priority + price cap fields; no condition-of-yours. |
| `wishshare` | Shared wishlist | Recipient sees "you own 3 of these"; owner learns nothing until the recipient explicitly taps to point (D28). |
| `hit` | Wishlist hit | Alert fires on full match only — print + grade + price cap (D30). |
| `reserve` | Reservation | A queued lend. Sketched, **not built** (D31). |

### Type system
| `screen` | Name | Purpose |
|---|---|---|
| `types` | All 14 types | One row per type, each using its own spine labels, mark, gradient, conditions and sample values, read from `Resources/Types/*.yml`. |
| `mixed` | Mixed-type collection | A collection holding more than one type. |

### Navigation chrome
| `screen` | Name | Purpose |
|---|---|---|
| `chrome` | B1 · chrome spec | Nav bar + tab bar rules: Close vs Back inside a modal, bottom bar as a layout with a presenting middle slot. |
| `tabs` | Five tabs, one too many | The problem statement. |
| `tabs2` | Five slots, two spoken for | Candidate pool scored against the three audiences. |
| `tabpick` | Profile pick | Second question in onboarding — which bar you get. |
| `tabedit` | Customise bar | Per-profile editing. |
| `playlist` | Dense list pressure test | F4 — a long playlist-style list at maximum density. |

### Board
`board` renders the whole set as a contact sheet.

---

## Interactions & behaviour

**Tab bar** — five slots, present on `home`, `collection`, `lending`, `stats`. Middle slot is a raised 40×40 circular scan button (`margin-top:-9px`, solid border, hard shadow). Inactive items are the same glyph at `opacity:.45`. The bar is a layout, not a fixed list: the middle slot presents rather than navigates, and the two outer pairs are configurable per profile (`tabpick`, `tabedit`).

**3D sleeve on `item`** — the single most important interaction.
- Idle: auto-rotates on Y, reversing direction at the bounds (`±` sweep, `0.18°` per frame at 60fps).
- Drag: pointer capture; `rotY += dx * 0.6` clamped to ±80°, `rotX -= dy * 0.4` clamped to ±60°. Auto-rotation pauses while dragging and resumes on release.
- Tapping the special-edition chip fires a sparkle burst lasting **950ms**, then clears. Gated on `specialEdition`; if false, the tap does nothing.
- The sleeve is a real 6-face CSS 3D box in the prototype; in SwiftUI use SceneKit/RealityKit or a rotating layered composite — the requirement is that it reads as a physical object with thickness, not a flipping card.
- A disc picker below swaps the record/disc colour; the selected one gets an ink ring, the others `rgba(243,236,224,.25)`.

**Segmented controls** (item tabs, stats tabs, scan modes) — active pill is `#17130F` with `#F3ECE0` text (or `#FFD24A` with ink text in the camera's dark context); inactive is transparent with ink or `rgba(243,236,224,.7)` text. No animation required beyond the default.

**Bottom sheets** (`lendsheet`, `enrich`, `promote`, `return`, `link`) — dimmed ink backdrop at `.28–.32` opacity, sheet `#F3ECE0` with a `2.5px` top border, `24px` top corners, a `46×5` `#C9BFB0` grabber, `14px 20px 34px` padding. Dismiss action is **Cancel** or **Close**, never Back.

**Money can be switched off entirely.** The `selling` prop drives a `money` / `noMoney` split: value lines, market tabs, price fields and the sell flow all disappear. This is a first-class mode, not a settings nicety — a large share of the audience does not want their collection priced. Implement it as a real capability flag through the whole app.

**Pro mode** (`pro` prop) applies a hue shift to the shell (`hue-rotate(-52deg) saturate(1.06)`) — an exploration of a dealer-facing skin. Low priority.

**`interactive: false`** disables all navigation and handlers — a prototype-only affordance for static capture. No production equivalent needed.

## State

From the prototype's logic class, the state a real implementation needs:

- `screen` — navigation. In SwiftUI this becomes a real navigation stack plus sheet presentation, not a flat enum; use the screen table above to decide which are pushes, which are sheets (`lendsheet`, `enrich`, `promote`, `return`, `link`), and which are tab roots (`home`, `lending`, `stats`).
- `tab` — object detail section: `overview | details | history | market`.
- `statsTab` — `coll | value`.
- `scanMode` — `barcode | photo | look`.
- `lookup` — identify on/off. When off, and in `offline`, barcodes are stored raw and enriched later.
- `crate` — continuous capture on/off.
- `disc` — selected disc index on the item screen.
- `rotX` / `rotY` / `dir` / `dragging` — 3D sleeve.
- `sparkBurst` — timestamp, cleared after 950ms.

Data fetching: catalogue lookups (barcode → object) are metered and can fail offline; every lookup path needs a queued/unresolved state (`offline` screen), and a manual-entry escape that never requires network (`notype`).

## Assets

No bitmaps, no icon fonts, no external images. Everything is CSS: borders, gradients, radial dot textures (`radial-gradient(#17130F 1.1px, transparent 1.2px)` at `7–9px` tiles), and typographic "marks" per collection type. Icons in the tab bar and chrome are geometric primitives, deliberately.

Fonts: Bricolage Grotesque (600, 800) and Archivo (400–700) and DM Mono (400, 500), all Google Fonts / OFL.

The type gradients, marks, spine labels and condition scales are **data**, and already exist in the repo at `CollectionCatalog/Resources/Types/*.yml` for all 14 types. Read them; do not re-author them in the UI layer.

## Product & business context

Read these before making trade-offs — several UI decisions only make sense against them.

| File | What it settles |
|---|---|
| `design/App Brief.dc.html` | Audiences, principles, what the app refuses to do |
| `design/Master Plan.dc.html` | Five phases, two go/no-go gates (month 8, month 15) |
| `design/Revenue Model.dc.html` | Five revenue meters, the free/paid boundary, founding-price ladder |
| `design/Business Plan.dc.html` | v1/v2/v3 scope, geography, gate metrics |
| `design/Growth Plan.dc.html` | 400 catalogued users, community co-creation |
| `design/Tagging and Metrics.dc.html` | **36-event first-party taxonomy — implement at v1 launch** |
| `design/Video Playbook.dc.html` | Eight clips; the 3D shelf is the hero asset |
| `design/decisions.md` | D27–D31 + shelved S1 |
| `design/Design System.dc.html` | The visual system, standalone |

Three constraints from those documents that are implementation-shaping:

1. **The free tier is 100 objects, and the cap is a ceiling, not a wall.** At object 101 the app saves the object, shows it, and *then* says the next one needs the unlock. Nobody ever loses work they typed. Build the cap check after the write, never before.
2. **Lookup credits are metered from v1** — 100/month free, 300 for unlock owners; manual entry always unlimited and free. Ship the counter in v1 even if no credit pack is sold; retrofitting it later is the expensive version.
3. **Two v2-gate events must ship at v1 launch**: `object_flagged_sellable` and `wish_added`. The month-8 go/no-go decision reads them (latent supply ≥8%, latent demand ≥30%). If they aren't instrumented on day one, the gate cannot be evaluated.

## Files in this bundle

```
design/
  CLCTN App.html              ← open this: standalone interactive prototype, 45 screens
  Collections App.dc.html     ← prototype source
  ios-frame.jsx, support.js   ← required alongside the source
  Design System.dc.html       ← visual system reference
  Screen Index.dc.html        ← contact sheet of all screens, grouped
  App Brief.dc.html
  Master Plan.dc.html
  Business Plan.dc.html
  Revenue Model.dc.html
  Growth Plan.dc.html
  Video Playbook.dc.html
  Tagging and Metrics.dc.html
  Collections.dc.html         ← earlier exploration, kept for reference
  decisions.md
  github.md                   ← repo pointer + screen→source map, last sync 2026-08-20
```

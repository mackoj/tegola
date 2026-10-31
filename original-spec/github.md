repo: mackoj/the-collection
branch: main

## Last sync

date: 2026-08-20T19:50:00Z

### Updated in this project

- Turn 14 reads all fourteen `Resources/Types/*.yml` files and shows one item row per type using each type's own spine labels, mark, gradient, conditions and sample values — plus mixed-type collections and the no-matching-type flow (sneakers is the permanent no-provider case).
- Turns 11–13 rework the tab bar: five-slot alternatives, a candidate pool scored against the three audiences, and a per-profile configurable/customisable bar.

- Read TODO.md, docs/product.md and docs/navigation.md as the brief for the screens the app is still missing.
- Added turn 9 to the board: 3D capture, insurance export, a co-owned shelf, the app's own nav chrome (B1), inspect mode (B4) and an incoming deep link.
- Turn 10 closes the last gaps: offline lookup failure, borrowed-not-owned, and part F's pressure test (dense playlist list + magic-link extension and web fallback).
- Nav chrome and the deep-link sheet follow docs/navigation.md: Close vs Back inside a modal, the bottom bar as a layout with a presenting middle slot, and a link opening over the current tab.

## Screen map

| Project screen | Repo source |
|---|---|
| `capture` — 3D capture | TODO.md B4/D3, `CollectorKit/SleeveHero.swift`, `Perspective3D.swift` |
| `inspect` — inspect mode | TODO.md B4, docs/product.md ("the design system and the 3D object" are real) |
| `insure` — valuation export | docs/product.md principle 1 (money is optional), StatsScreen |
| `coshelf` — co-owned shelf | TODO.md C8, docs/decisions.md D23–D25 |
| `chrome` — nav bar + tab bar spec | TODO.md B1, docs/navigation.md |
| `link` — incoming deep link | docs/navigation.md (deep links, `dismissModal`) |
| `offline` — lookup with no network | docs/product.md principles 4–6, TODO C4 |
| `borrowed` — things that aren't yours | LendingLogScreen, docs/data-model.md |
| `playlist` / `magic` — F4 pressure test | TODO.md part F (F1–F4) |
| `types` / `mixed` / `notype` | `CollectionCatalog/Resources/Types/*.yml` (all 14) |
| `tabs` / `tabs2` / `tabpick` / `tabedit` | TODO.md B1, docs/navigation.md |
| Existing turns 1–8 | `Packages/Sources/*Screen/`, `CollectionsRoot/ScreenBoard.swift` |

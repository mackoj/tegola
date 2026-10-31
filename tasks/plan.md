# Implementation plan

Source of truth: `docs/PLAN.md` (spec) and `docs/DECISIONS.md`. This file breaks each milestone into tasks. A task is
one commit (or one PR) on the milestone's branch; this cloud session pushes to `claude/tegola-rearchitecture-jcq29f`
(PLAN §10, answer 7). A milestone ends with a report in `docs/milestones/M<n>.md` and a merge into `main`.

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

Exit test: 30 objects added across Video games and Thing in one sitting without asking how. Design-system components
and the catalog; Shelf home; Collection; Object (seven slots); Edit form (form renderer per field kind); Add by hand;
Find and search; the item level (Signed, Bundle of, Place, photos).

## M4 · signals (P2)

Exit test: a 200-object shelf gives a signal list a collector agrees with on 8 of 10. Clocks; ladder and set
signatures; status derivation; the Today strip as the signal feed; dismissals; local notifications.

## M5 · launch types + first piece (P3)

Exit test: 5 of 6 testers finish onboarding with one complete object. Music, Video games, Board games, Thing as data;
first-piece onboarding (46); type inference via `ExtractionClient`.

## M6 · capture, lookup, import (P4)

Exit test: `Jeux collection.csv` imports in under 3 minutes with under 5% of rows needing a fix. Camera (VisionKit);
`LookupClient` with App Attest middleware; lookup queue; review queue; enrichment; Importer API and the three v1
importers; batch undo.

## M7 · people · M8 · keeping + you · M9 · polish

Lending, Activity, share cards; wishlist, let go, archive, saved views, settings, export, inventory document,
nudges, analytics, debug screen; French, accessibility, journeys, performance. Broken down when M6 merges.

# Todo

## M1 · foundation (branch `claude/tegola-rearchitecture-jcq29f`)

Plan: `tasks/plan.md`, M1. Report: `docs/milestones/M1.md`.

- [x] T1.1 Repo skeleton: configs, scripts, CI
- [x] T1.2 Packages (seven; `TegolaStorage` moves to M2, D-31)
- [x] T1.3 Lookup client generated from the contract, with contract tests
- [x] T1.4 Design tokens, the Board theme, contrast tests, fonts
- [x] T1.5 Guard tests
- [x] T1.6 Fixtures (`Jeux collection.csv`, recorded server responses)
- [x] T1.7 App shell: `Tegola.xcodeproj`, `AppFeature`, unit and UI tests
  - [x] Mac run: `scripts/test.sh app`, `scripts/test.sh TegolaFeatures`, `scripts/test.sh TegolaDesignSystem`
    (font registration), `scripts/ci.sh`: green on 2026-10-31, Xcode 27.1 (`docs/milestones/M1.md`)
- [x] T1.8 Docs: DECISIONS, GLOSSARY, ui-tests, HANDOFF, briefs, M1 report

## M2 · catalogue + model + storage (branch `m2-catalogue-model-storage`)

Plan: `tasks/plan.md`, M2. Report: `docs/milestones/M2.md`.

- [x] T2.1 Type schema v1 and its JSON Schema
- [x] T2.2 Type files move to subtypes (video games, music)
- [x] T2.3 Resolver and the subtype rules (exit test: 13 subtypes)
- [x] T2.4 Item level, clock library, signature kit
- [x] T2.5 Domain values and `ShelfCommand`
- [x] T2.6 `plan` and `apply`, with the promise property tests
- [x] T2.7 `TegolaStorage`: schema, `perform`, projection, replay test
- [x] T2.8 `ShelfClient`, seed shelf, docs, review

## M3 · core loop (branch `m3-core-loop`)

Plan: `tasks/plan.md`, M3. Report: `docs/milestones/M3.md`.

- [x] T3.1 Snapshot harness and the first components
- [x] T3.2 Read side: Route, ShelfSummary, TodayStrip, ObjectSlots, the money switch, promises 4 and 5
- [x] T3.3 Navigation: tab bar, stacks, Path, routes, `--screen`
- [x] T3.4 Shelf home and the empty shelf
- [x] T3.5 Collection
- [x] T3.6 Object: seven slots, ladder and set, history
- [x] T3.7 Edit form, and `plan`'s value checks
- [x] T3.8 Add by hand
- [x] T3.9 Photos
- [x] T3.10 Find and saved views
- [x] T3.11 Places
- [x] T3.12 Journeys, seed, docs, review

## M4 · signals (branch `m4-signals`)

Plan: `tasks/plan.md`, M4. Report: `docs/milestones/M4.md`.

- [x] T4.1 Clock functions: `Signal`, one function per library clock, the save-battery tests
- [x] T4.2 Type files and the library: `discRot-pending`, `codeExpires` and `codeExpiry`, `unfinished`
- [x] T4.3 Status derivation, and real statuses for `ShelfSummary` and `TodayStrip`
- [x] T4.4 Dismissals: command, event, plan rules, projection
- [x] T4.5 The object's status slot: reason, Estimate, Dismiss, Log a battery swap
- [x] T4.6 The signal feed from the Today strip
- [x] T4.7 Status filters in Collection and Find
- [x] T4.8 Notifications: `NotificationsClient`, the offer, scheduling
- [x] T4.9 Seed toward 120 objects, and the 200-object signal test
- [x] T4.10 Journey 5, docs, review

## M5 · launch types + first piece

Plan: `tasks/plan.md`, M5. Report: `docs/milestones/M5.md`.

- [x] T5.1 Type guess
- [ ] T5.2 First-piece rules
- [ ] T5.3 Type testers
- [ ] T5.4 The payoff
- [ ] T5.5 `ExtractionClient` (Mac)
- [ ] T5.6 Onboarding (Mac)
- [ ] T5.7 The empty shelf (Mac)
- [ ] T5.8 Journey and review

## Open follow-ups

- Generate App Attest's `appattest-environment` entitlement with M6, when the lookup client first runs on a device.

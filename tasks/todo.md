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
- [ ] T2.7 `TegolaStorage`: schema, `perform`, projection, replay test
- [ ] T2.8 `ShelfClient`, seed shelf, docs, review

## Open follow-ups

- Generate App Attest's `appattest-environment` entitlement with M6, when the lookup client first runs on a device.

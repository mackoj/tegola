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

## M2 · catalogue + model + storage

Broken down at the start of M2 (`tasks/plan.md`).

## Open follow-ups

- Generate App Attest's `appattest-environment` entitlement with M6, when the lookup client first runs on a device.

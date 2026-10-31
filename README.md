# Tegola

Tegola is a private catalogue for iPhone, for people who own things on purpose: records, books, games, wine, and
anything else. For every object it answers four questions: **what is it, where is it, who has it, and what happened to
it.** It works offline, with no account, and only talks about money if you ask it to.

It is a from-scratch rebuild of the product that `mackoj/clctn` and `mackoj/the-collection` attempted. The product
decisions come from clctn's decision log (`PD-###`). The repo layout, tooling and architecture follow `mackoj/telaio`:
SwiftUI, The Composable Architecture and local Swift packages, in the Swift 6 language mode.

**Status: Milestone 1 (foundation) done.** The spec is [`docs/PLAN.md`](docs/PLAN.md), approved with the answers in
its §10; the design boards are in [`docs/design/BOARDS.md`](docs/design/BOARDS.md). M1's report is
[`docs/milestones/M1.md`](docs/milestones/M1.md); next is M2, the catalogue, model and storage.

## Build and test

```sh
scripts/test-linux.sh              # the pure packages, on any machine with Swift 6.4 (Linux CI runs this on every push)
scripts/test.sh                    # on the Mac: only what this branch changed (xcrun, Xcode 27.1)
scripts/ci.sh                      # on the Mac: the full gate before a milestone merges
scripts/lint-api.sh                # the lookup contract (api/tegola-lookup.openapi.yaml)
python3 scripts/generate-xcodeproj.py .   # after changing the project's shape
```

Open `Tegola.xcodeproj` in Xcode 27.1 and run the `Tegola` scheme on an iPhone simulator. Signing is automatic; set
your team to run on a device.

## Packages

| Package | Role | Linux |
|---|---|---|
| `TegolaCatalogue` | The type files and the code that reads and validates them | ✅ |
| `TegolaModel` | Domain values and rules (money, places, status, the tab bar; objects and commands from M2) | ✅ |
| `TegolaInterchange` | Import and export (the delimited-text reader; importers from M6) | ✅ |
| `TegolaLookupAPI` | The tegola-server client, generated from the OpenAPI contract | ✅ |
| `TegolaDesignSystem` | `TegolaDesignTokens` (pure) and the SwiftUI design system | tokens ✅ |
| `TegolaFeatures` | One target per TCA reducer (`AppFeature` in M1) | Mac only |
| `TegolaTestSupport` | Fixtures and the guard tests | ✅ |

## Project docs

| Document | What it holds |
|---|---|
| `docs/PLAN.md` | The specification: what's different from the prompt (§0), capability map (§1), stack, commands, structure, style, testing and boundaries (§2), core model (§3), features F1–F17 (§4), TCA tree (§5), privacy and CI (§6), open questions (§10) |
| `docs/design/BOARDS.md` | The prototype's screens, rendered from the original archive, with text descriptions, a component inventory and the token table |
| `api/tegola-lookup.openapi.yaml` | The lookup contract between the app and `mackoj/tegola-server` (OpenAPI 3.1, App Attest security). The app's client is generated from it |
| `original-spec/` | The original design archive: 50 design pages, the interactive prototype, type files and a real collector's spreadsheet. The source the spec is drawn from |
| `docs/DECISIONS.md` | D-1 to D-33: how the spec is read where it's unclear |
| `docs/GLOSSARY.md` | The words collectors read |
| `docs/milestones/M<n>.md` | One report per milestone |
| `tasks/plan.md`, `tasks/todo.md`, `tasks/HANDOFF.md` | Milestones and tasks, progress, and the state of the work |
| `CLAUDE.md` | Working notes for coding agents |

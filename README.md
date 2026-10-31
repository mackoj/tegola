# Tegola

Tegola is a private catalogue for iPhone, for people who own things on purpose: records, books, games, wine, and
anything else. For every object it answers four questions: **what is it, where is it, who has it, and what happened to
it.** It works offline, with no account, and only talks about money if you ask it to.

It is a from-scratch rebuild of the product that `mackoj/clctn` and `mackoj/the-collection` attempted. The product
decisions come from clctn's decision log (`PD-###`). The repo layout, tooling and architecture follow `mackoj/telaio`:
SwiftUI, The Composable Architecture and local Swift packages, in the Swift 6 language mode.

**Status: specification, for review.** There is no code yet. The spec is [`docs/PLAN.md`](docs/PLAN.md), and the
design boards are in [`docs/design/BOARDS.md`](docs/design/BOARDS.md). Scaffolding starts after the spec is approved.

## Project docs

| Document | What it holds |
|---|---|
| `docs/PLAN.md` | The specification: what's different from the prompt (§0), capability map (§1), stack, commands, structure, style, testing and boundaries (§2), core model (§3), features F1–F17 (§4), TCA tree (§5), privacy and CI (§6), open questions (§10) |
| `docs/design/BOARDS.md` | The prototype's screens, rendered from the original archive, with text descriptions, a component inventory and the token table |
| `original-spec/` | The original design archive: 50 design pages, the interactive prototype, type files and a real collector's spreadsheet. The source the spec is drawn from |
| `CLAUDE.md` | Working notes for coding agents |

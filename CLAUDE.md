# Tegola: working notes for Claude

## Token & Execution Policy
- Aggressively preserve context: summarize and clear history between distinct phases.
- Offload heavy tasks, multi-file analysis and reviews to cloud agents when the work doesn't need the Mac.
  - Cloud runs have no Xcode, so app builds, snapshot tests and UI tests stay on the Mac. The pure packages
    (`TegolaCatalogue`, `TegolaModel`, `TegolaInterchange`) build and test on Linux (`scripts/test-linux.sh`).
  - Each prompt must stand alone. Point it at the repo docs, and restate the attribution rule (no Claude trailers or
    footers).
- Continuously evaluate the test harness to reduce boilerplate and prompt token waste.

## Project rules
- **Spec:** `docs/PLAN.md` is the specification, and `docs/DECISIONS.md` records the spec interpretations (`D-n`).
  Product decisions are clctn's `PD-###` log, cited by id; changing one is the owner's call. The design boards, as
  images with text descriptions, are in `docs/design/BOARDS.md`. The original spec is `original-spec/`.
- **Process:** `tasks/plan.md` and `tasks/todo.md` track milestones and tasks. Each milestone ends with a report in
  `docs/milestones/M<n>.md`. `tasks/HANDOFF.md` is the state of the work for whoever picks it up next.
- **Toolchain:** always use `xcrun swift …` and `xcodebuild` on the Mac. If swiftly is installed, the `swift` on PATH
  is its open-source toolchain, which breaks swift-snapshot-testing.
- **Tests:** `scripts/test.sh` runs only what a branch changed (`scripts/test.sh <Package> [<Suite>]`, or
  `scripts/test.sh app`); `scripts/ci.sh` runs the full gate. Pipe long output through `xcsift -f toon`. CI runs the
  Linux core on every push; the macOS job runs only when started by hand.
- **Workflow:** one task, one commit or PR into the milestone branch; a separate review agent before a milestone is
  marked ready; a milestone branch merges into `main` once its report is written.
- **Writes:** every change to the shelf is a `ShelfCommand` through `ShelfClient`. Nothing is confirmed, merged or
  overwritten on a collector's behalf; history only appends; wanted, borrowed and let-go objects never count; a log
  line or an analytics event records shape, never content.
- **Attribution:** commits and PRs carry no Claude trailers or footers.

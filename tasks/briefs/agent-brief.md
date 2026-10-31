# Brief for an implementation agent

You are implementing one task of a Tegola milestone. Read, in this order: `CLAUDE.md`, the task in `tasks/plan.md`,
the PLAN sections it cites, and any `D-` entries in `docs/DECISIONS.md` it touches.

## Rules from the owner

- The spec is `docs/PLAN.md`; product decisions are the `PD-###` log and PLAN §10. Don't change either: if the task
  needs a reading the spec doesn't give, add a `D-` entry and carry on with it.
- Every write to the shelf is a `ShelfCommand` through `ShelfClient`. Nothing is confirmed, merged or overwritten on a
  collector's behalf; history only appends; wanted, borrowed and let-go objects never count.
- Views use design-system components and theme roles, never palette colours, font names or literal sizes.
- No `Date()`, `UUID()`, `Locale.current`, `Calendar.current`, `URLSession.shared` or `print` in sources: use the
  dependency. The guard tests enforce this.
- Every user-facing string goes through a String Catalog with `bundle: .module`, with a French entry.
- Commits and PRs carry no AI-assistant trailers or footers.

## How to work

1. Write the test first (`test-driven-development`), named after what a collector sees.
2. Keep `TestStore`s exhaustive; a non-exhaustive one needs a comment saying why.
3. Every view gets a `#Preview` per state, fed by the seed shelf.
4. Before committing: `scripts/test-linux.sh` (pure packages) or `scripts/test.sh` (Mac), and
   `swift format lint --strict` over what you touched. Zero warnings.
5. One commit per task, message saying what changed and why, citing PD/D numbers.

## Final message (under 400 words)

What you built, the tests you added and their result, where they ran (Linux or Mac), anything you couldn't verify,
and any new `D-` entries.

# Handoff

The state of the work for whoever picks it up next: a new session, another agent, or the owner. Read this first, keep
it short and current.

**Updated:** 2026-10-31, M2 merged into `main` (PR #8). M3 is in progress on `m3-core-loop`.

## Where things stand

- **Spec:** approved (`docs/PLAN.md`, answers in §10). Decisions: `docs/DECISIONS.md`, D-1 to D-42.
- **M1 (foundation):** merged (PR #5), green on the Mac (`docs/milestones/M1.md`).
- **M2 (catalogue, model, storage):** merged (PR #8, `docs/milestones/M2.md`). Exit test
  green: the 13 subtypes resolve to their written-out field lists. `scripts/ci.sh` is green on Xcode 27.1, and
  `linux-core` is green.
- **What exists now:**
  - type files on schema v1, with subtypes, the item level, and the clock and signature libraries;
  - the resolver (`Catalogue.resolve`);
  - the pure `plan` and `apply`, with property tests for six of the eight promises;
  - `TegolaStorage` (event log and projection in one transaction, with a replay test);
  - `ShelfClient` and the seed shelf;
  - the app opens its database at launch.
- **No screens yet** beyond M1's placeholder. They start in M3.
- **tegola-server** (`mackoj/tegola-server`, D-41): its M1 is done (see What's next).

## Run it locally (Mac)

Needs Xcode 27.1 (Swift 6.4) with an iOS 26 or 27 simulator runtime. Node is optional (only for the API lint).

```sh
git clone https://github.com/mackoj/tegola.git && cd tegola

scripts/test.sh TegolaDesignSystem   # tokens + the font tests that only run on Apple platforms
scripts/test.sh TegolaStorage        # the event log, the projection and the replay test (sqlite-data)
scripts/test.sh TegolaFeatures       # AppFeature and ShelfClient (first run resolves TCA: a few minutes)
scripts/test.sh app                  # builds the app, runs TegolaTests and TegolaUITests on a simulator
scripts/ci.sh                        # the full gate → build/ci-summary.md
```

- `scripts/test.sh app` picks the newest available iPhone simulator. Set `DESTINATION='platform=iOS Simulator,name=…'`
  to choose one.
- Or open `Tegola.xcodeproj` in Xcode and run the `Tegola` scheme. Signing is automatic. To run on a device, set your
  team in the target's Signing settings.
- If `swift` on your PATH is swiftly's toolchain, the scripts are unaffected, because they use `xcrun`. Don't run
  `swift test` directly.
- **What you should see:** still M1's placeholder: a paper-coloured screen titled "Shelf" and a row of five tab
  labels. M2 has no UI; the database it opens at launch is empty unless the app is launched with `--seed` (debug
  builds). The real tab bar and screens arrive in M3.

**If anything fails:** paste `build/ci-summary.md`, and the failing log it names, into a session.

## What's next

1. **M3, the core loop**, on `m3-core-loop`: twelve tasks in `tasks/plan.md`, ticked in `tasks/todo.md` (exit test: 30 objects added across Video games and Thing in one sitting without asking how).
   Roughly:
   - the design-system components and their catalog snapshots;
   - Shelf home with `ShelfSummary`, and promises 4 and 5 as properties over screen state;
   - Collection, Object (seven slots), and the edit form, rendering `EffectiveType.visibleFields` with "+ Add" for
     `addableFields`;
   - Add by hand, and Find and search (`objects_fts` arrives here);
   - photos (the `photos` table and `attachPhoto`).

   Add `plan`'s value checks (D-40) with the edit form. Every write is a `ShelfCommand` through `ShelfClient`; screens read through queries on the projection's columns,
   and decode `data` for the full value.
2. **In parallel, tegola-server** (`mackoj/tegola-server`, D-41): its M1 is done. It serves the contract with
   Hummingbird 2, verifies App Attest end to end, and has every security control, but no lookup source yet (lookups
   answer "no match"). Its `tasks/HANDOFF.md` lists the owner questions (sources, hosting, persistence, Team ID). The
   app's client only needs it from M6 on. When M6 writes `AppAttestMiddleware`, build the signed bytes exactly as the
   contract now says (D-42).

## How the work is run

- **Branch:** one milestone branch, started from `main`, with one commit per task and one PR per milestone into `main`
  (PLAN §10, answer 7).
- **Package.resolved:** resolving on a Mac drops OpenCombine, which TCA needs only on Linux. Commit new pins, but
  put OpenCombine's pin back (M2 did this for `TegolaFeatures` and the Xcode project).
- **Type files:** `scripts/validate-types.sh` checks them against `schema/type.schema.json`; the decoder and
  `Catalogue.problems` check the rest. A new key goes in both the decoder and the schema.
- **Toolchain in a cloud session:** there's no Xcode and no Swift by default.
  - download.swift.org and GitHub release downloads are blocked, and Docker Hub and AWS ECR rate-limit the shared
    address.
  - Google's Docker Hub mirror works. Fetch the `amd64` manifest of `mirror.gcr.io/library/swift:6.4.2-noble` over its
    registry API, download and extract the layers into `/opt/swiftroot`, and run commands with
    `chroot /opt/swiftroot`.
  - Bind-mount the repo, `/proc` and `/dev`, copy `/etc/resolv.conf` and the proxy CA into the root, and pass the
    proxy environment and `SSL_CERT_FILE` through.
  - Then `scripts/test-linux.sh` runs the pure core and storage (install `libsqlite3-dev` in the root first, for
    GRDB), and `swift format lint --strict` works too.
- **The Xcode project** is generated: change `scripts/generate-xcodeproj.py`, run it, commit both.
- **The lookup contract** is `api/tegola-lookup.openapi.yaml`. Run `scripts/lint-api.sh` before committing a change
  to it, and the generated client's contract tests run with `TegolaLookupAPI`. Then sync it into tegola-server
  (`scripts/sync-contract.sh` there) and keep the server building (D-41).
- **Reviews:** before a milestone is marked ready, a separate review agent reads it against the plan. It's worth the
  most on code that couldn't be compiled where it was written.
- **Attribution:** commits and PRs carry no AI-assistant trailers or footers.

## Known issues

- TCA doesn't build on Linux with Swift 6.4 (swift-navigation's `TextState`), so feature tests only run on the Mac
  (D-32).
- SwiftUI can't set line spacing below a font's natural leading, so the 0.96 line height of the two-line display
  titles needs the DisplayTitle component (M3). Until then, display titles render with default leading.

## Owner questions

None blocking. Two readings in M2 are worth a look (`docs/milestones/M2.md`, "For the owner"):
- D-35: music lost its per-medium field names (Sleeve, Case, J-card);
- D-38: imported rows are confirmed.

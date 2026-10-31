# Handoff

The state of the work for whoever picks it up next: a new session, another agent, or the owner. Read this first, keep
it short and current.

**Updated:** 2026-10-31, M1 merged into `main` and green on the Mac. M2 is next.

## Where things stand

- **Spec:** approved (`docs/PLAN.md`, answers in §10). Decisions: `docs/DECISIONS.md`, D-1 to D-33.
- **M1 (foundation):** merged into `main` (PR #5). A separate review found 14 problems, all fixed
  (`docs/milestones/M1.md`, "Review").
- **Verified:** on Linux (Swift 6.4.2), the six pure packages. On the Mac (Xcode 27.1), the full gate,
  `scripts/ci.sh`: every package, the app's unit and UI tests, the lints and the secret scan
  (`docs/milestones/M1.md`).

## Run it locally (Mac)

Needs Xcode 27.1 (Swift 6.4) with an iOS 26 or 27 simulator runtime. Node is optional (only for the API lint).

```sh
git clone https://github.com/mackoj/tegola.git && cd tegola

scripts/test.sh TegolaDesignSystem   # tokens + the font tests that only run on Apple platforms
scripts/test.sh TegolaFeatures       # AppFeature's TestStore tests (first run resolves TCA: a few minutes)
scripts/test.sh app                  # builds the app, runs TegolaTests and TegolaUITests on a simulator
scripts/ci.sh                        # the full gate → build/ci-summary.md
```

- `scripts/test.sh app` picks the newest available iPhone simulator. Set `DESTINATION='platform=iOS Simulator,name=…'`
  to choose one.
- Or open `Tegola.xcodeproj` in Xcode and run the `Tegola` scheme. Signing is automatic. To run on a device, set your
  team in the target's Signing settings.
- If `swift` on your PATH is swiftly's toolchain, the scripts are unaffected, because they use `xcrun`. Don't run
  `swift test` directly.
- **What you should see:** a paper-coloured screen titled "Shelf" in Bricolage Grotesque, and a row of five tab
  labels. Tapping one changes the title; Scan opens a dark sheet. That's the whole of M1's UI. The real tab bar and
  screens arrive in M3.

**If anything fails:** paste `build/ci-summary.md`, and the failing log it names, into a session.

## What's next

1. **M2, catalogue + model + storage** (page 52 P0; exit test: the 13 subtypes of `video-game.yml` and
   `video-media.yml` resolve to the right field lists). Break it down in `tasks/plan.md` first. Roughly:
   1. The type schema in full, plus a JSON Schema that CI validates every type file against.
   2. Subtypes and the resolver. Write page 48's five video-game subtypes into `video-game.yml`, and turn music's
      `mediumRules` into format subtypes (D-18).
   3. The item level (Signed, Bundle of), the clock library, and the signature kit.
   4. Domain values: `ShelfObject`, `Work`, `ShelfEvent`, `ShelfCommand`, and the pure
      `plan(command) -> [ShelfEvent]`.
   5. `TegolaStorage` on sqlite-data:
      - the schema under `SyncEngine`'s rules (D-24);
      - `ShelfClient.perform`, with the event log and its projection written in one transaction;
      - the replay test;
      - the seed shelf.

   Items 1 to 4 build and test on Linux. Whether sqlite-data and GRDB build on Linux is the first thing to check in
   item 5. If they don't, storage tests are Mac-only, like the features.
2. **In parallel, tegola-server:** the contract it implements is `api/tegola-lookup.openapi.yaml`, including App Attest.
   The app's client only needs the server from M6 on, so there's no rush.

## How the work is run

- **Branch:** one milestone branch, started from `main`, with one commit per task and one PR per milestone into `main`
  (PLAN §10, answer 7).
- **Package.resolved:** resolving on a Mac drops OpenCombine, which TCA needs only on Linux. Don't commit that
  change.
- **Toolchain in a cloud session:** there's no Xcode and no Swift by default.
  - download.swift.org and GitHub release downloads are blocked, and Docker Hub and AWS ECR rate-limit the shared
    address.
  - Google's Docker Hub mirror works. Fetch the `amd64` manifest of `mirror.gcr.io/library/swift:6.4.2-noble` over its
    registry API, download and extract the layers into `/opt/swiftroot`, and run commands with
    `chroot /opt/swiftroot`.
  - Bind-mount the repo, `/proc` and `/dev`, copy `/etc/resolv.conf` and the proxy CA into the root, and pass the
    proxy environment and `SSL_CERT_FILE` through.
  - Then `scripts/test-linux.sh` runs the pure core, and `swift format lint --strict` works too.
- **The Xcode project** is generated: change `scripts/generate-xcodeproj.py`, run it, commit both.
- **The lookup contract** is `api/tegola-lookup.openapi.yaml`. Run `scripts/lint-api.sh` before committing a change
  to it, and the generated client's contract tests run with `TegolaLookupAPI`.
- **Reviews:** before a milestone is marked ready, a separate review agent reads it against the plan. It's worth the
  most on code that couldn't be compiled where it was written.
- **Attribution:** commits and PRs carry no AI-assistant trailers or footers.

## Known issues

- TCA doesn't build on Linux with Swift 6.4 (swift-navigation's `TextState`), so feature tests only run on the Mac
  (D-32).
- SwiftUI can't set line spacing below a font's natural leading, so the 0.96 line height of the two-line display
  titles needs the DisplayTitle component (M3). Until then, display titles render with default leading.

## Owner questions

None open. The twelve spec questions are answered (PLAN §10).

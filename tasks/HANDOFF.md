# Handoff

The state of the work for whoever picks it up next: a new session, another agent, or the owner. Read this first, keep
it short and current.

**Updated:** 2026-10-31, end of M1.

## Where things stand

- The spec is approved (`docs/PLAN.md`, answers in §10). Decisions: `docs/DECISIONS.md`, D-1 to D-33.
- M1 (foundation) is done and verified on Linux: 68 tests in the six pure packages, zero warnings, zero swift-format
  findings, API lint clean. The app, `AppFeature` and the font registration are written but **not yet built**: they
  need the Mac (see `docs/milestones/M1.md`, "Not verified").
- Next: M2, catalogue + model + storage (page 52 P0). Break it down in `tasks/plan.md` first.

## How the work is run

- **Branch:** one cloud session pushes to `claude/tegola-rearchitecture-jcq29f`, one commit per task, one PR per
  milestone into `main` (PLAN §10 answer 7).
- **Toolchain in a cloud session:** no Xcode and no Swift by default. A Swift 6.4.2 Linux toolchain can be pulled from
  Google's Docker Hub mirror (`mirror.gcr.io/library/swift:6.4.2-noble`; Docker Hub and AWS ECR rate-limit the shared
  address, and download.swift.org is blocked) and run with `chroot`, bind-mounting the repo and the proxy's CA. Then
  `scripts/test-linux.sh` runs the pure core.
- **On the Mac:** `scripts/test.sh` (focused), `scripts/ci.sh` (full gate), always through `xcrun`.
- **The Xcode project** is generated: change `scripts/generate-xcodeproj.py`, run it, commit both.
- **The lookup contract** is `api/tegola-lookup.openapi.yaml`; `scripts/lint-api.sh` before committing a change to it.
- **Attribution:** commits and PRs carry no AI-assistant trailers or footers.

## Known issues

- TCA doesn't build on Linux with Swift 6.4 (swift-navigation's `TextState`), so feature tests only run on the Mac
  (D-32).

## Owner questions

None open. The twelve spec questions are answered (PLAN §10).

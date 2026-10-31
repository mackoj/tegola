# Tegola: plan and specification (Milestone 1, for review)

**Status:** draft, waiting for your review. No code yet. Nothing in Phase 2 (scaffolding) starts until you approve
this document. §10 lists the questions where your answer would change what I build; each has a default that I'll use
if you don't answer.

**What Tegola is.** A from-scratch rebuild of the collection app that `mackoj/clctn` and `mackoj/the-collection` both
attempted: a private catalogue for iPhone, for people who own things on purpose. It answers four questions about every
object: **what is it, where is it, who has it, and what happened to it**. Product decisions are taken from the existing
decision log (`PD-###`, below). Repo layout, tooling, process and architecture are taken from `mackoj/telaio`.

**What I read for this plan:**

- your prompt, all of it;
- **the original spec, `original-spec/`** in this repo: the design pages `00_Design System` … `53_Marketplace`, the
  interactive prototype `35_Collections App.dc.html` (45 screens), the handoff bundle `design_handoff_clctn/` (tokens,
  screen table, interactions), `decisions.md` (D27–D31, S1), the type files and `uploads/Jeux collection.csv`. Every
  file it shares with `mackoj/clctn/design/` at `f6479f9` is byte-identical. It adds the October 2026 pages 46–53
  (first-piece onboarding, a friend's feedback on video games, subtypes, the import pipeline, a pricing calculator,
  Video Media, the implementation plan, the marketplace) and `video-media.yml`. It lacks `45_Judgement Experiments`,
  which this plan doesn't rely on;
- `mackoj/clctn` at `f6479f9`: `CONTEXT.md`, `docs/product/SPEC.md` (17 features, 206 stories), `DECISIONS.md`
  (PD-001 to PD-166), `ROADMAP.md` (confirmed 2026-09-23, PD-164), the seven journeys, ADR-0001 to ADR-0009, the
  engineering notes, the 17 type manifests in `Sources/TypeCatalogue/Types/*.yml`, and the code (surveyed);
- `mackoj/the-collection` at `28f45db`: `docs/*.md`, `TODO.md`, `DesignReview/`, and the code (surveyed);
- `mackoj/telaio` at `c9ac92f`: `CLAUDE.md`, `README.md`, `REVIEW.md`, `docs/PLAN.md`, `docs/DECISIONS.md` (format),
  `tasks/`, `scripts/`, `.github/`, every `Package.swift`, and its TCA, dependency, test and design-system code;
- `mackoj/swift-keychain`, `swift-har`, `swift-jsonpath`, `swift-arazzo` (public): package layout, platforms and Swift
  settings, as examples of how a focused mackoj package is cut.

**Toolchain.**

- **Target Mac** (where builds, app tests and UI tests run, as in telaio): Xcode 27.1, Swift 6.4, iOS 27 SDK, an
  iPhone 17 simulator.
- **This cloud container**: Linux, **no Swift toolchain and no Xcode**. I can install the open-source Linux toolchain
  here to build and test the packages that import no Apple UI framework (§2.6, §6). Nothing that imports SwiftUI,
  UIKit, VisionKit or CloudKit can be built here (Q6).

---

## 0. Summary: what's different from the prompt

Where the prompt and the blueprint disagree, I follow the blueprint, as the prompt's own rule says ("replicate the
exact repo skeleton and dev-ops ecosystem of telaio").

| # | Topic | Prompt says | Reality | Plan |
|---|---|---|---|---|
| 1 | `original-spec/` | A site archive folder provided in the repo | It's in the repo now (added after this plan's first draft). Its September pages are the same files as `mackoj/clctn/design/`; its October pages (46–53) are newer than the PD log. | `original-spec/` is the source. The prototype's screens are rendered to `docs/design/boards/` with text descriptions in `docs/design/BOARDS.md`, the way telaio keeps its boards. Row 15 says how the October pages and the PD log are reconciled. |
| 2 | Config files | `.swiftformat`, `.swiftlint.yml`, `.editorconfig`, mise/tool versions | telaio has **none** of these. It has `.swift-format` (Apple's swift-format, 2-space indent, 120 columns), `.periphery.yml` and `.gitignore`. | Copy telaio's three files. No SwiftLint, SwiftFormat, EditorConfig or mise. |
| 3 | Git hooks | Replicate them | telaio has none. clctn has `.githooks/pre-commit` with guards worth keeping: no `Date()`, `UUID()`, `Locale.current` or `URLSession.shared` in source targets, and no hand-bound SQL. | No hooks, to match telaio. The guards become **guard tests**, like telaio's `DesignSystemGuardTests`, so they run in every test pass and in CI instead of only on machines that installed a hook. |
| 4 | Handoff templates | Replicate them | telaio has `tasks/HANDOFF.md` and `tasks/briefs/*` (agent brief, `TestStore` brief) plus milestone reports `docs/milestones/M<n>.md`. | Same files, rewritten for tegola. |
| 5 | Scope | Faithfully implement the spec | The product spec has 17 features and 206 stories. The roadmap, confirmed as PD-164, cuts v1 to five types and an iPhone-only app, and PD-160 removes everything that needs a backend (loan links, share links, the type board). | **Tegola v1 = the confirmed v1 roadmap, narrowed by PD-160 and PD-166** (§4). v1.x, v2 and v3 items are listed (§4.3) but not built. |
| 6 | Architecture "exactly as telaio" | Same state, reducer, dependency and navigation patterns | telaio is a **document** app: one `DocumentValue` per window, saved to a file. Tegola is a **library** app (one catalogue, a database). | Keep telaio's shape and swap the substrate. Telaio has one value per window, edits as `DocumentEdit` values, and only the root mutates. Tegola has **one database**: every write is a `ShelfCommand` value, and only `ShelfClient.perform(_:)` writes, in one transaction that also appends the history (§3.2). Views read through `@FetchAll`/`@FetchOne`. |
| 7 | CI | Mirror telaio's pipelines | telaio's `ci.yml` is manual-only. Its own `REVIEW.md` (recommendation 1) says this is the biggest risk: nothing independent checks `main`. | Mirror `ci.yml` (manual, `macos-26`), and **add one automatic Linux job** that builds and tests the pure packages on every push (§6). That follows telaio's own review. |
| 8 | Previews with mock data | `#Preview` with TCA mock state and test dependencies | clctn's rule: every state of every view gets a preview, fed by one shared seed shelf. | Same rule. `TegolaTestSupport.Seed` installs the same shelf in previews, reducer tests and UI tests (§2.6). |
| 9 | Two legacy apps disagree | Use both as feature reference | the-collection (D1–D35) predates clctn's PD log. For example: a loan reason is required (D-era) vs optional (PD-123); there are 14 vs 17 types; the 3D sleeve is the hero vs shelved (PD-145); pro mode; crate mode. | **The PD log wins.** It is newer and was confirmed by you in the grilling rounds. The-collection is used for the visual record (the design review and the 3D-free parts of `CollectorKit`). |
| 10 | Handoff bundle constraints | — | `design_handoff_clctn/README.md` asks for a 100-object free-tier cap and a lookup-credit meter shipped in v1. Both are superseded: PD-112 defers the free/paid split, and PD-118 says there is no visible meter. | Neither is built. Every add path still goes through one place (`ShelfCommand.add`) so a cap can be added later without reworking a screen (PD-112, consequence). |
| 11 | Attribution | — | telaio's and clctn's `CLAUDE.md` both forbid AI-assistant trailers and footers on commits and PRs. | Tegola's `CLAUDE.md` carries the same rule, and I follow it from the first commit. |
| 12 | Navigation "as in telaio" | Same navigation patterns | telaio has no `StackState` and no `NavigationStack`: a document window never drills down, so every presentation is a `@Presents` optional (or an `IdentifiedArray` for step windows), and children ask the root through `.delegate`. An iPhone tab app needs drill-down. | Keep telaio's rules (`@Presents` for every sheet, children ask the root by delegate, only the root changes navigation) and add one `StackState<Path.State>` per tab, owned by the root (§5). |
| 13 | telaio contradicts itself | — | Its `CLAUDE.md` and PLAN say squash merges and a review agent per PR, while its HANDOFF and agent brief say merge commits and no review agents. `ci.sh` lints less than the briefs say. PLAN names a non-existent `TelaioDesignSystemSystem`. | I copy the files as they are actually used: merge commits, the lint scope written once in `ci.sh` and covering every Swift directory, and real package names. The review step is in §9. |
| 14 | What the legacy code teaches | — | The clctn survey found these, among others: every `TestStore` non-exhaustive (68 of 68); Edit, Lend and Let go routed only from the Shelf tab; import undo hard-deleting objects the collector had since edited; imported rows stamped *acquired* (against PD-165); the seed shelf compiled into Release; the design system used by one screen, with no fonts bundled; three different dashed edges; status swatches as system colours. the-collection is a static prototype with no persistence. | Each one becomes a rule or a test here: exhaustive `TestStore`s by default (§2.6); one `Path` with routing tested from every tab (§5); batch undo that keeps what was touched (D-12); no `acquired` written by the app (§3.4 promise 7); `Seed` behind `#if DEBUG` (§2.4); every screen built from `TegolaDesignSystem` and checked against its board (§2.7); one `notYours()` modifier (§4.0). |
| 15 | October pages vs the PD log | — | Pages 46–53 (October 2026) are newer than the PD log (confirmed 2026-09-23), and most are marked **PROPOSAL**. Some refine the product without contradicting it: subtypes (48), item-level Signed and Bundle of (48), a work layer above the object (47), the event log as truth, money in cents (52), the first-piece flow (46), and the import pipeline's shape (49). **Three conflict with confirmed decisions:** a backend for matching and cover art (49, 52 P4) vs no backend in v1 (PD-160); accounts, sync and a €50/year subscription as v1's last phase (52 P5, 50) vs no account (ADR-0001) and a deferred payment shape (PD-112, PD-113); and a Stripe marketplace (53, v2) vs "no checkout, escrow or take rate, ever" (PD-084). | Adopt the refinements (§3, F1, F2, F9, D-16 to D-22). Follow page 52's phase order and exit tests for the milestones (§1). For the three conflicts, keep the PD log in v1 until you say otherwise (Q9). The marketplace is v2 either way, so it changes nothing now. |

---

## 1. Capability map

These module ids are stable. Branch names, PR titles and the task list all use them.

| Module id | Responsibility | Depends on |
|---|---|---|
| `foundation` | Packages, Xcode project, scripts, CI, swift-format, guard tests, fonts, fixtures, the seed shelf | none |
| `catalogue` | Type manifests: decoding, validation, field kinds, condition scales and ladder parts, spine labels, bulk rule, clocks from the library, type verb; the item level; subtypes and the resolver. The v1 types ship enabled. | foundation |
| `model` | Domain values and rules: Object, Work, Collection, Place, Person, Loan, ShelfEvent (the log), ownership and lifecycle, `ShelfCommand`, status and clock derivation, never-merge and money rules | catalogue |
| `storage` | SQLite schema and migrations, `ShelfClient` (one write path), queries, the full-text index, photo storage, the launch migration screen's runner | model |
| `design-system` | Tokens, the three fonts, every shared component, the "not yours" rule, a snapshot catalog | foundation |
| `shelf` | Shelf home, Collection, Object (seven slots), Edit form, Places, History, Archive | storage, design-system |
| `adding` | First piece (onboarding), Add by hand, Capture (photo and barcode), lookup, look-alike choice, the review queue, enrichment, the offline lookup queue | shelf |
| `interchange` | CSV and Discogs import (mapping, batch undo); CSV and JSON export; the inventory document (PDF) | storage, design-system |
| `find` | Search over every field and entry, filter chips, "what matched", Stats | storage, shelf |
| `people` | Persons, lending, returns, borrowed objects, Activity, share cards (sent from the collector's side only) | shelf |
| `keeping` | Wishlist, grail, Might let go, Let go and the archive, quantity and promote, wine (open a bottle, Drunk, the drinking-window clock) | shelf |
| `you` | Settings, the money switch, the tab editor, language, nudges and notifications, shape-only analytics, the hidden debug screen | all features |
| `polish` | French, VoiceOver, Dynamic Type, the journeys as UI tests, performance on a 2,000-object shelf, empty states | all |

**Build order.** It follows `52_Implementation Plan` ("build the verbs once, ship the nouns as data"), with each of
its exit tests as the milestone's gate. The v1-roadmap features that page doesn't place come after it.

| Milestone | Modules | Page 52 phase | Exit test |
|---|---|---|---|
| M1 | foundation, design-system tokens | none (repo) | Every package builds; guard, contrast and catalog tests pass |
| M2 | catalogue, model, storage | P0 Foundations | Loading `video-game.yml` and `video-media.yml` gives the right field list for all 13 subtypes, with tests |
| M3 | design-system components, shelf, adding by hand, find | P1 Core loop | Someone adds 30 objects across Video games and Thing in one sitting without asking how |
| M4 | clocks, signatures, the signal feed (Today) | P2 Signals | A 200-object test shelf gives a signal list a collector agrees with on 8 of 10 |
| M5 | the five launch types, first piece | P3 Launch types + onboarding | 5 of 6 testers finish onboarding with one complete object and can say what the app will tell them |
| M6 | capture, lookup, review queue, interchange | P4 Lookup and import | `Jeux collection.csv` (485 games) imports in under 3 minutes, with under 5% of rows needing a fix |
| M7 | people, places, Activity | none (roadmap v1) | The lend-at-the-door journey passes |
| M8 | keeping, you (export, inventory, money, nudges) | none (roadmap v1); P5's export | Export → import gives the same shelf |
| M9 | polish | none | All six journeys pass; performance targets met |

P5 (accounts, sync, pricing) waits for Q9.

`catalogue`, `model` and `interchange`'s parsers have no UI and build on Linux, so they can run ahead of the UI
milestones in their own worktree. Each module still merges in milestone order.

---

## 2. Specification

### 2.1 Objective

Tegola is a native iPhone app that catalogues the physical objects a collector owns, wants, lends or once owned. It
answers four questions about each one: what is it, where is it, who has it, and what happened to it (PD-001). The line
is "Know what you own." (PD-003).

- **Users:** three audiences in one app with no modes (PD-002, PD-163). The Hardcore has 400+ objects and knows the
  grading scale. The Hobbyist has 60–150 and lends to friends. The Owner has one inherited collection and will never
  learn a scale. The app never asks which one you are.
- **The core loop** (ROADMAP): *a collector gets their objects in, sees a shelf worth looking at, finds any object,
  and knows who has the ones that aren't there.*
- **Success:**
  - every "Done when" line in §4 (F1–F17) has a named automated test that passes (§2.9);
  - the six walkable journeys (§4.4) pass as UI tests from a cold launch with an empty catalogue;
  - the cross-cutting promises (§3.4) hold as parameterised tests, run once per v1 type;
  - every screen matches its board in `docs/design/BOARDS.md`, checked by snapshot tests at iPhone 17 size.

### 2.2 Tech stack

| Item | Choice |
|---|---|
| Language | Swift 6 language mode, strict concurrency, built with Swift 6.4 (Xcode 27.1). Upcoming features `ExistentialAny`, `InternalImportsByDefault` and `MemberImportVisibility` are on in every package, as in telaio. |
| Platform | iPhone only in v1 (PD-160). Minimum **iOS 26.0** (ADR-0005), built against the iOS 27 SDK. Code that needs SDK 27 sits behind `#if compiler(>=6.4)` and `if #available(iOS 27, *)`, with an iOS 26 fallback, as telaio does for macOS. |
| UI | SwiftUI. UIKit only where SwiftUI has no equivalent: `DataScannerViewController` (VisionKit) for live barcode and text capture, and `UIGraphicsPDFRenderer` for the inventory document. |
| State | TCA `1.26.x` (`@Reducer`, `@ObservableState`, `@ViewAction`, `StackState` navigation, `@Presents`) |
| Storage | `pointfreeco/sqlite-data` `1.12.x` (GRDB underneath), with the `StrictDecoding` and `Tagged` traits, and `@Table` models from swift-structured-queries. It is local-first and CloudKit-ready from the first migration (ADR-0006); sync stays off in v1 (Q4). |
| Type manifests | YAML files bundled as resources, decoded with `jpsim/Yams` `6.x` |
| Dependencies | swift-dependencies `1.17.x` for every effectful boundary (clock, date, uuid, locale, network, camera, photos, notifications, files) |

Packages beyond TCA, one line each:

| Package | Why |
|---|---|
| pointfreeco sqlite-data, swift-structured-queries, swift-tagged | Typed tables and queries, observation that works inside `@ObservableState`, CloudKit sync later without changing the schema. clctn already proved it on this domain. |
| jpsim/Yams | The 17 type manifests are YAML, and they stay hand-editable and diffable. |
| pointfreeco swift-sharing, swift-identified-collections, swift-case-paths, swift-custom-dump, swift-issue-reporting, swift-clocks | They come with TCA. They are listed so targets can import them directly. |
| pointfreeco swift-snapshot-testing | Board fidelity and the design-system catalog. Test targets only. |
| apple swift-async-algorithms | Debouncing the search field and the lookup queue |

**Fonts.** Bricolage Grotesque (variable), Archivo (variable) and DM Mono (Regular and Medium), all SIL OFL. The
files are already in `the-collection/Packages/Sources/CollectorKit/Resources/Fonts`, with their licences. They go into
`TegolaDesignSystem/Resources/Fonts`, registered once at launch with `CTFontManagerRegisterFontsForURL`, with the
`wght`/`opsz` axes set per style. Never SF Pro as a substitute (handoff README).

**Not added:** a CSV parser (an in-house RFC 4180 reader that sniffs the separator and encoding, about 300 lines,
because the import has to accept anything a spreadsheet writes); a fuzzy matcher (in-house, as in telaio); an
analytics SDK (events stay on the device, PD-095, PD-162); a font loader (the fonts are registered from the
design-system bundle); swift-configuration (clctn's `configuration.yml` becomes a typed `Tunables` value with
defaults in Swift. One file format fewer, and the "missing key keeps the default" rule still holds).

### 2.3 Commands

```sh
# Whole app (unit tests, package tests, snapshot tests and UI tests) on the Mac, iOS 27 SDK
xcodebuild test -project Tegola.xcodeproj -scheme Tegola \
  -destination 'platform=iOS Simulator,name=iPhone 17' -resultBundlePath build/Tegola.xcresult

# One package, quickly
xcrun swift test --package-path Packages/TegolaModel

# Focused tests: only the packages and feature targets this branch changed against its base
scripts/test.sh                                # diffs against origin/main or the nearest origin/m<N>/* branch
scripts/test.sh TegolaModel                    # one package
scripts/test.sh TegolaFeatures ShelfFeatureTests   # one test target
scripts/test.sh app | app-unit | ui            # the app

# The full gate before a milestone merge: every package, the app, UI tests, swift-format lint, secret scan
scripts/ci.sh                                  # → build/ci-summary.md

# The pure core on Linux (this container, and the automatic CI job)
scripts/test-linux.sh                          # TegolaCatalogue, TegolaModel, TegolaInterchange

# Lint and format
xcrun swift-format lint --strict --recursive Packages Tegola
xcrun swift-format format --in-place --recursive Packages Tegola

# Dead code
scripts/periphery.sh
```

As in telaio, always use `xcrun swift …` on the Mac. If swiftly is installed, the `swift` on `PATH` is its
open-source toolchain, and that breaks swift-snapshot-testing.

### 2.4 Project structure

```
Tegola.xcodeproj               kept minimal: app, unit-test and UI-test targets, local package references
Tegola/                        app target: @main, the root scene, Info.plist, entitlements, Localizable.xcstrings,
                               live values that need the app (notifications delegate), the --reset/--seed/--screen
                               launch arguments (#if DEBUG)
TegolaTests/                   app-level unit tests (launch arguments, root wiring, font registration)
TegolaUITests/                 XCUITest: the journeys (§4.4) and one flow per screen
Packages/
  TegolaCatalogue/             TypeManifest, FieldKind, ConditionScale, Subtype, the resolver, the clock library, the manifests as resources
  TegolaModel/                 domain values, ShelfCommand, rules (lifecycle, loans, status, clocks, money, places)
  TegolaStorage/               schema, migrations, ShelfClient (+Live), queries, full-text index, PhotoStore
  TegolaInterchange/           CSV reader, Discogs mapping, column guesser, exporters (CSV, JSON), inventory model
  TegolaDesignSystem/          tokens, fonts, components, the DesignSystemCatalog snapshot suite
  TegolaFeatures/              one target per reducer (§5) plus TegolaClients
  TegolaTestSupport/           fixtures (CSV files, a Discogs export, lookup payloads), Golden, StringCatalogCoverage,
                               helpers; linked by test targets only
scripts/                       test.sh, ci.sh, test-linux.sh, secret-scan.sh, periphery.sh, sync-strings.sh,
                               xcresult-summary.py, xcstrings-*.py, ui-screenshots.sh
docs/PLAN.md                   this file
docs/DECISIONS.md              how Tegola reads the spec where it is unclear (D-1 …)
docs/design/BOARDS.md          the prototype's screens as images with text descriptions; boards/*.png
docs/milestones/M<n>.md        one report per milestone
docs/testing/ui-tests.md       which checks are UI tests, and why
tasks/plan.md, tasks/todo.md   milestones and tasks (planning-and-task-breakdown)
tasks/HANDOFF.md, tasks/briefs/  how to pick up the work; agent and TestStore briefs
.github/workflows/ci.yml       linux-core on every push; macos job by workflow_dispatch only
.swift-format, .periphery.yml, .gitignore, CLAUDE.md, README.md
```

As in telaio:

- every manifest starts `// swift-tools-version: 6.2` with the shared `swiftSettings` (the three upcoming features);
- each package that shows text has `defaultLocalization: "en"` and a `Resources/Localizable.xcstrings`;
- snapshot test targets `exclude: ["__Snapshots__"]`;
- the Xcode project is hand-written and minimal: synchronized folder groups, build settings inline (no xcconfig), and
  references to the local packages the app links directly.

**The seed shelf.** `Seed` (the shared shelf every preview and test sees, about 120 objects across the five types, in
the spirit of clctn's `Persona`) lives in `TegolaStorage` behind `#if DEBUG`. Previews, `--seed` and the tests use
it, and Release never contains it. clctn linked its `TestSupport` into every feature target, so its seed shipped.

Package dependency graph (no cycles):

```
TegolaDesignSystem ──────────────────────────────────────────┐
TegolaCatalogue ──► TegolaModel ──► TegolaStorage            │
                         │               │                   ▼
                         └──► TegolaInterchange ──► TegolaFeatures ──► Tegola (app)
TegolaTestSupport ──► TegolaCatalogue, TegolaModel, TegolaStorage, TegolaInterchange (test targets only)
```

- **Linux-buildable:** `TegolaCatalogue`, `TegolaModel` and `TegolaInterchange`. They import Foundation, Yams and
  StructuredQueriesCore only, never SwiftUI, UIKit, `os` or SQLite. A guard test enforces it.
- **Where clients live:** as in telaio, a `TegolaClients` target inside `TegolaFeatures` holds every client's interface
  with its test and preview values. Live values that touch the system are in files named `*+Live.swift`.
  `ShelfClient` is the one exception: its live value lives in `TegolaStorage`, because it *is* the storage.
- **Features never import each other** (ADR-0005). They send `.delegate` actions, and the root composes them (§5).

### 2.5 Code style

- `swift-format` with telaio's `.swift-format`: 2-space indent, 120 columns, `OrderedImports`, with force-try and
  force-unwrap rules off. That is how pointfreeco code is formatted.
- Every reducer uses `@Reducer` with `@ObservableState` state. Actions split into `view`, `delegate` and `internal`
  (telaio's REVIEW found `internal` under-used; here every effect result is an `internal` case).
- Views never compute a business rule and never write. A write is a `ShelfCommand` sent to `ShelfClient`.
- A form edits the record's generated `Draft` (`@Table` gives one) and nothing else. Values that edit differently from
  how they are stored (a year that is `Int?` but typed as text) use a `Binding` adapter, never a shadow property
  (clctn rule).

```swift
@Reducer
public struct LendFeature {
  @ObservableState
  public struct State: Equatable {
    public let objectID: ShelfObject.ID
    public var personName = ""
    public var due: Loan.Due = .none
    public var note = ""
    @FetchAll(Person.recentFirst) public var recentPeople: [Person]
    public var canLend: Bool { !personName.trimmingCharacters(in: .whitespaces).isEmpty }
  }

  public enum Action: ViewAction {
    case view(View)
    case `internal`(Internal)
    case delegate(Delegate)

    public enum View: Equatable {
      case personNameChanged(String)
      case dueChanged(Loan.Due)
      case noteChanged(String)
      case lendTapped
      case cancelTapped
    }
    public enum Internal: Equatable { case lendFailed(ShelfError) }
    public enum Delegate: Equatable { case lent(Loan.ID), cancelled }
  }

  @Dependency(\.shelf) var shelf
  @Dependency(\.date.now) var now

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(.personNameChanged(name)): state.personName = name; return .none
      case let .view(.dueChanged(due)): state.due = due; return .none
      case let .view(.noteChanged(note)): state.note = note; return .none
      case .view(.cancelTapped): return .send(.delegate(.cancelled))
      case .view(.lendTapped):
        guard state.canLend else { return .none }
        let command = ShelfCommand.lend(state.objectID, to: .named(state.personName), due: state.due.date(from: now),
                                        note: state.note)
        return .run { send in
          let receipt = try await shelf.perform(command)
          await send(.delegate(.lent(receipt.loanID!)))
        } catch: { error, send in
          await send(.internal(.lendFailed(ShelfError(error))))
        }
      case .internal, .delegate: return .none
      }
    }
  }
}
```

- Naming:
  - types are `UpperCamel`, and IDs are `Tagged` (`ShelfObject.ID`, `Person.ID`), so they can't be mixed up;
  - the domain words are the glossary's (§3.0): `ShelfObject` (because `Object` collides), `Collection` → `ShelfCollection`, `Place`, `Person`, `Loan`, `Work`, `ShelfEvent`. The words the app never uses (PD-101), such as "item" and "user", never appear in UI copy;
  - acronyms are `ID`, `URL`, `CSV`, `JSON`, `PDF`;
  - test files are `<Subject>Tests.swift`. Swift Testing (`@Test`, `#expect`) is used everywhere except UI and
    performance tests, which use XCTest.
- No hex colour, font name or point size outside `TegolaDesignSystem/Tokens/`. No `print`. Logging goes through
  `os.Logger` with `privacy: .private` by default, and a log line records shape, never content: no titles, prices or
  names (CLAUDE.md rule; telaio's REVIEW found `.public` errors). This is enforced by a guard test.
- No `Date()`, `UUID()`, `Locale.current`, `Calendar.current` or `URLSession.shared` in a source target. Use the
  dependency instead. This is a guard test (§0 row 3).
- Every user-facing string is in a String Catalog and passes `bundle: .module` inside packages (telaio REVIEW §7). A
  guard test fails on a SwiftUI text initialiser with a literal and no `bundle:` in a package.

### 2.6 Testing strategy

| Level | Tool | What it covers |
|---|---|---|
| Unit | Swift Testing, in each package | Manifest decoding and validation for all 17 manifests; field-kind parsing; condition axes; `Place` path parsing and near-duplicate detection; loan state machine; status and clock derivation; money visibility; CSV sniffing (separator, encoding, dates); column guessing; exporters |
| Property | Seeded generators (Swift Testing arguments, 300 seeds) | The cross-cutting promises (§3.4) over random command sequences; export → import round-trip gives the same objects; parsing any `Place` path and printing it again gives the same string |
| Storage | Swift Testing on an in-memory database | Migrations from empty; every `ShelfCommand` writes the expected rows and exactly the expected history; batch undo removes exactly the batch; full-text search finds a single track on an LP |
| Reducer | `TestStore`, **exhaustive** (non-exhaustive only with a comment saying why), every dependency overridden, the seed shelf in an in-memory database | The main actions of every reducer, and every `Route` opened from every tab. A feature is done only when its "Done when" line has a test. |
| Snapshot | swift-snapshot-testing (`.image`, iPhone 17 layout, 2×, light; `precision: 0.99`, `perceptualPrecision: 0.98`) | The `DesignSystemCatalog` (every component, every variant) and every screen in every state its previews show. These PNGs are the milestone screenshots. |
| UI | XCUITest, launched with `--reset` (and `--seed` where a journey starts with a shelf) | The six journeys end to end, with no `--screen` shortcut (§4.4), plus one flow per screen opened with `--screen <name>` |
| Guard | Swift Testing, scanning the sources | No hex, named system colour (`Color.red`, `UIColor.…`) or font name outside tokens (telaio's `DesignSystemGuardTests`); no world access outside dependencies; no un-bundled UI string literal; every String Catalog key used, none missing, each with a French entry (telaio's `StringCatalogCoverageTests`); Linux-buildable packages import no Apple UI framework; no `.public` log interpolation |
| Contrast | Swift Testing | Every text/background pair in the tokens at 4.5:1 or above, or listed as an exception with the reason (telaio's `ContrastTests`). Measured on the archive's hex values: ink on paper 15.74:1, muted `#6E6458` on paper 4.93:1 (but 3.88:1 on paper deep), **meta `#8A7F70` on paper 3.34:1**, paper on orange 2.63:1, paper on teal `#12A594` 2.62:1, paper on pink 3.27:1. The last four fail AA at the 9–13 px sizes the boards use (Q8). |
| Performance | XCTest `measure` | Shelf, Collection and Find on a 2,000-object seed: first frame under 100 ms, search results under 150 ms after the last keystroke (M11) |

**Previews.** Every view ships a `#Preview` for every state its state type admits: empty, populated, loading, error,
money on/off, wanted/borrowed, Dynamic Type XXL. Each one is named for its state. Screens that read the database get
their data from the shared seed: `let _ = prepareDependencies { try! $0.bootstrapDatabase(); try! Seed.install() }`.
A new product state goes into the seed first, so every preview and every test sees it.

**Where tests run.** As in telaio, the app, snapshot and UI tests run on the Mac (`scripts/test.sh`, `scripts/ci.sh`).
The pure packages also run on Linux, in this container and in the automatic CI job, so `main` gets an independent
check on every push.

### 2.7 Boundaries

- **Always:**
  - run `scripts/test.sh` (focused) before every task merge and `scripts/ci.sh` before every milestone merge, and
    paste the summary into the PR. On a branch where no Mac run was possible, the PR says so in its first line;
  - build UI only from `TegolaDesignSystem` components. A new visual pattern goes into the design system first, with a
    catalog snapshot;
  - write to the shelf only through `ShelfCommand`;
  - check a screen against its board before calling it done;
  - one PR per task, linked to its section of this plan;
  - record a spec interpretation as a new `D-` entry in `docs/DECISIONS.md`, then carry on with that reading.
- **Ask first:**
  - adding a dependency from an org other than pointfreeco, apple, swiftlang, jpsim or mackoj;
  - any change to a product decision (`PD-###`) or to the v1 scope in §4;
  - changing the bundle id, the entitlements or the minimum OS after M1;
  - turning on CloudKit sync, or anything that makes data leave the device (lookups excepted, PD-118);
  - deleting or rewriting anything on `main` outside a PR, or force-pushing a branch that isn't mine.
- **Never:**
  - confirm, merge or overwrite anything on a collector's behalf (PD-042, PD-045, PD-047, PD-151);
  - delete an object to "let it go", or update or delete a history event (PD-051, PD-149);
  - count wanted, borrowed or let-go objects in a total (PD-061, PD-070);
  - show a value with the money switch off (PD-080);
  - send a photo anywhere except through Identify (PD-118);
  - log or record titles, prices, names or barcodes in analytics or logs (PD-095);
  - disable or delete a failing test to get a merge through;
  - add AI-assistant trailers or footers to commits or PRs.

### 2.8 Apple guidance and skills, by area

Before writing code in an area, I (or the subagent doing the work) load the matching skill. Apple's guidance wins over
memory.

| Area | Skill | What it changes in this plan |
|---|---|---|
| Every SwiftUI view | `swiftui-specialist` | Small `View` structs; inputs narrowed to what a view reads; stable `ForEach` ids (object ids, never indices); no soft-deprecated APIs |
| SDK 27 APIs | `swiftui-whats-new-27` | `@State` is a macro: no `@State` assigned in `init`. The design system never names a type after a SwiftUI type (`TegolaColor`, not `Color`). Gated with iOS 26 fallbacks: `swipeActions` outside `List` for collection rows, `reorderable()` for the tab editor, `alert`/`confirmationDialog(item:)` for Let go and Delete. |
| Window sizes | `app-resizability` | iPhone only, but no `UIScreen.main`, no idiom checks: layouts adapt to width, so iPad later costs nothing |
| TCA, dependencies, sharing, SQLiteData, testing | the Point-Free skills (`pfw-composable-architecture`, `pfw-dependencies`, `pfw-sqlite-data`, `pfw-structured-queries`, `pfw-testing`, `pfw-snapshot-testing`) where installed, else the libraries' own docs | Reducer, dependency, query and `TestStore` conventions in §2.5 and §5 |
| Process | `planning-and-task-breakdown`, `incremental-implementation`, `test-driven-development`, `code-review-and-quality`, `git-workflow-and-versioning`, `pr` | §9 |

### 2.9 Success criteria

Each feature's "Done when" has a named test. The milestone report lists each test with its result.

| Feature | Test (target/name) |
|---|---|
| F1 | `TegolaCatalogueTests.everyManifestDecodesAndValidates`, `.v1TypesAreTheFiveEnabled` |
| F2 | `FirstPieceFeatureTests.aNamedPieceLandsOnTheShelfWithItsStoryAndNoAcquiredDate`, `TegolaUITests.testTheFirstPiece` |
| F3 | `ShelfFeatureTests.todayStripShowsOnlyNonEmptyLines`, `ShelfSnapshotTests.populatedMoneyOff` |
| F4 | `ObjectFeatureTests.sevenSlotsInOrderForEveryV1Type` (parameterised by type) |
| F5 | `ObjectEditFeatureTests.cancelLeavesTheObjectUntouched`, `.saveAppendsOneHistoryEvent` |
| F6 | `CaptureFeatureTests.firstObjectOfATypeCreatesItsCollection`, `.addToDefaultsToTheLastUsedCollection` |
| F7 | `LookAlikeTests.neverMergesAndOffersThreeChoices`, `MatchFeatureTests.saysYouAlreadyOwnThisUnprompted` |
| F8 | `ReviewQueueFeatureTests.confirmAllConfirmsOnlyStrongMatches`, `EnrichmentTests.fillsOnlyEmptyFieldsAfterAsking` |
| F9 | `ImportIntegrationTests.jeuxCollectionLandsAsOneCollectionWithAShelfPerPlatform`, `.everyCellIsKept`, `.notesBecomePartsSignedAndBundles` (recorded model outputs), `.undoKeepsWhatWasTouched` |
| F10 | `PlaceTests.typingAPathCreatesNestedPlaces`, `PlacesFeatureTests.screenAppearsOnlyOnceTwoPlacesExist` |
| F11 | `SearchTests.findsASingleTrackOnAnLP`, `FindFeatureTests.chipsStackAndEachResultSaysWhatMatched`, `SavedViewTests.imperfectListsMissingOrWornParts` |
| F12 | `StatsTests.groupedByTypeNeverAveragedAcrossTypes` |
| F13 | `LendingIntegrationTests.lendAtTheDoorInThreeTapsThenOneSidedReturnIsInHistory`, `TegolaUITests.testLendAtTheDoor` |
| F14 | `ShareCardTests.paidIsNeverOnACard` (both kinds, money on and off) |
| F15 | `WineTests.openingTheLastBottleMovesItToDrunkAndKeepsIt`, `QuantityTests.promotedCopyIsItsOwnObjectAndLendable` |
| F16 | `LetGoTests.archivedObjectsStillAnswerDidIEverOwnThis`, `WishlistTests.flippingOwnedKeepsHistory` |
| F17 | `ExportTests.exportThenImportGivesTheSameShelf`, `InventoryDocumentTests.saysItIsNotAnAppraisalAndHasNoValuesWithMoneyOff`, `MoneyPropertyTests.moneyOffShowsNoValueOnAnyScreen` |

---

## 3. Core model

### 3.0 Vocabulary

The words come from clctn's `CONTEXT.md`. They're used in code, copy and tests. M1 ports the full glossary to
`docs/GLOSSARY.md`; these are the ones the model rests on.

| Term | Meaning | Avoid |
|---|---|---|
| Collector | The person whose shelf it is | user, account |
| Object | One physical thing owned, wanted or held for someone else | item, entry |
| Shelf | Everything the collector owns, across collections; also the first tab | library, inventory |
| Collection | A named group of objects, usually of one type; a **mixed** collection has none | folder, category |
| Type | The definition of one kind of collectible: nouns, spine labels, fields, scale, bulk rule, lookup, signatures, clock, type verb. The app owns the verbs; the type owns the nouns. | category, template |
| Spine | Title, subtitle, year, plus acquired, paid and value, relabelled by the type | |
| Field | A typed fact beyond the spine; its **kind** decides the control, the sort and the search | |
| Condition scale / axis | The type's own ordered grading words, best first; up to three axes on one scale | rating, score |
| Bulk rule | **rows** (each copy is an object) or **quantity** (a count on one object) | |
| Place | A physical location, created by typing, nested with `›` | location field |
| Person | Someone you lend to or borrow from, created by typing a name | contact |
| Loan | An object lent to a Person, with an optional due date and note | checkout |
| History | The append-only story of an object | log (as the slot name) |
| Unconfirmed / Needs details | A guessed identity not yet agreed / a photo with nothing identified | draft |
| Wanted / Borrowed | Not yours: a dashed edge, no shadow, never counted | wishlist item |
| Let go | Leaving the shelf for good, with a reason; kept in the archive | delete |
| Status | One chip from five swatches: fine · good · watch · act · gone | |
| Clock | A type's one derived, time-based estimate, always labelled **Estimate** | timer, alert |

### 3.1 One database, read through projections

The catalogue is one local SQLite database (ADR-0006). It's the only source of truth.

- **Reads** are `@FetchAll`/`@FetchOne` queries held in `@ObservableState` state. The Shelf header, the Today strip,
  a collection's rows and the object's slots are each a query or a pure function over query results (`ShelfSummary`,
  `TodayStrip`, `ObjectSlots`). Derived numbers are never stored.
- **Writes** are `ShelfCommand` values. Each one goes through `ShelfClient.perform(_:) -> CommandReceipt`, which:
  1. checks the command against the rules in `TegolaModel` (for example, a quantity object can't be lent until a copy
     is promoted; a let-go object can't be lent; a wanted object has no condition);
  2. turns it into **events** (`TegolaModel.plan(command, on: snapshot) -> [ShelfEvent]`, a pure function) and appends
     them to the `events` log;
  3. applies the same events to the current-state tables (`objects`, `loans`, …) **in the same transaction**;
  4. returns a receipt (created ids, the batch id, anything a delegate needs).
- **The event log is the source of truth** (page 52: "every change is an event; current state is derived from it").
  The tables are a projection kept up to date in the same write, so screens read plain rows and indexes, and
  `rebuildProjection()` can recreate them from the log. A storage test replays the log of a random command sequence
  and checks the rebuilt tables match the live ones, the way telaio checks its projections. A collector's **history**
  slot is the object's events, filtered to the kinds a person reads. The same log gives batch undo (an import is one
  batch of events), sync later (upload the log, merge per field), and clocks over time.
- Undo is per command where the product asks for it (edit form Cancel never writes; import and migration batches undo
  by batch id for 30 days, PD-047). There is no general undo stack; telaio's two-stack problem doesn't arise.

`ShelfCommand` (first cut; each case cites the decision that defines it):

```
add(ObjectDraft, to: CollectionChoice, origin: .typed | .captured(Capture) | .imported(batch) | .firstPiece(Story))  PD-137, PD-165, PD-166
confirm([ID]) · fillIn(ID, Draft) · applyEnrichment(ID, fields: Set<FieldKey>)                                        PD-042, PD-045
edit(ID, Draft)                         // the edit form's Save; appends `edited` with the changed keys only       PD-050
attachPhoto(ID, PhotoRef) · setPlace([ID], PlacePath?)                                                               PD-053
logEvent(ID, kind: .serviced | .cleaned | …, at:, note:)                                                             story 54
lend(ID, to: PersonRef, due: Date?, note: String) · returnLoan(LoanID, condition: String?, closedBy: .collectorOnly) PD-123, PD-148, PD-160
markBorrowed(ID, from: PersonRef) · giveBack(ID)                                                                     PD-061
setOwned(ID, Bool) · setWanted(priority:, priceCap:) · setGrail(ID, Bool) · setMightLetGo(ID, Bool)                PD-070, PD-126
letGo(ID, reason: .sold(price?) | .gifted | .traded | .lost | .broken)                                               PD-149
promote(ID) · adjustQuantity(ID, by: Int) · openBottle(ID, occasion:, note:, score:)                                 PD-020, PD-021
renameCollection · moveObjects([ID], to: CollectionID) · mergePlaces(PlaceID, into: PlaceID)                        stories 83, 109
importBatch(ImportPlan) · undoBatch(BatchID)                                                                          PD-047
```

### 3.2 Schema (first migration)

Every synced table uses a TEXT primary key holding a **ULID** and `deletedAt` soft deletes from the first migration, so
CloudKit or another sync can be turned on later without retrofitting keys (ADR-0006). ULIDs sort by creation time,
which the event log needs, and come from a `ulid` dependency so tests are deterministic (page 52). No unique constraints
beyond the key: two devices can create the same place offline, so the app detects duplicates and offers a merge.
**Money** is always integer minor units plus an ISO currency (`paid`, `value`, `priceCap`, `letGo.price`), never a
float and never without its currency (page 52).

| Table | Columns (abridged) |
|---|---|
| `events` | id (ULID), objectID?, batchID?, kind, payload JSON, at, source (`collector`/`capture`/`lookup`/`import`/`app`). **Append-only; the source of truth.** |
| `works` | id, title, typeID, externalIDs JSON (Wikidata, IGDB, MusicBrainz, Open Library): one work, many objects (Doom on six platforms, a film on three formats) |
| `collections` | id, name, typeID? (nil = mixed), purpose? (story 196), sortKey, createdAt |
| `objects` | id, collectionID, typeID, **subtype?**, **workID?**, **contains** JSON (work ids; two or more makes a bundle), **signed** JSON? (by, dedication, date, proof photo), **spine:** title, subtitle?, year?, acquiredAt?, paid?, value?; condition?, axes JSON, placeID?, notes; quantity (1 for rows), ownership (`owned`/`wanted`/`borrowed`), identity (`confirmed`/`unconfirmed`/`needsDetails`), grail, mightLetGo, priority?, priceCap?, letGo JSON?, parentID? (parts, v1.x), `fields` JSON (type and own fields), `auto` JSON (keys filled by a lookup, PD-042), createdAt, updatedAt |
| `objectEntries` | id, objectID, fieldKey, position, values JSON, searchText (list and log fields flattened, so one track is findable, ADR-0007) |
| `ownFields` | id, scope (`object`/`collection`/`type`), scopeID, key, label, kind (PD-130 kinds only) |
| (history) | No table of its own: the History slot reads `events` for the object, filtered to the kinds a collector reads (`added`, `acquired`, `edited`, `confirmed`, `photo`, `placed`, `lent`, `returned`, `borrowed`, `gaveBack`, `serviced`, `regraded`, `opened`, `promoted`, `letGo`, `owned`, `note`). |
| `places` | id, name, parentID?, createdAt |
| `persons` | id, name, lastUsedAt |
| `loans` | id, objectID, personID, direction (`out`/`in`), dueAt?, note?, openedAt, closedAt?, closedBy (`collector`/`both`), returnCondition? |
| `photos` | id, objectID, position, fileName (files on disk, outside the database), takenAt |
| `importBatches` | id, source (`csv`/`discogs`), fileName, rowCount, mapping JSON, createdAt, undoneAt? |
| `lookupQueue` | id, objectID, identifier (barcode/ISBN/OCR text), attempts, lastTriedAt, state |
| `settings` | key, value: only what the collector changed (PD-161, ADR-0008) |
| `objects_fts` | FTS5 over spine, notes, field values, entry `searchText`, place path, person names |

Analytics live in a **separate** database that never syncs (ADR-0006, ADR-0009).

### 3.3 Types are data

A type is a YAML manifest: the 17 files in clctn's `Sources/TypeCatalogue/Types/`, plus `original-spec/video-media.yml`
and the newer `video-game.yml`, `wine.yml`, `artwork.yml`, `retro-computer.yml` and `thing.yml` in `original-spec/`.
Its schema is: `id`, `version`, `name {hobby, singular, plural, collection}`, `mark`, `icon`, `gradient [a, b]`,
`duplicates: rows | quantity`, `consumable`, `spine` labels, `conditions` (best first), `allowMissing`, `lookup
{identifier, symbologies, providers, ocrFields}`, `searchable`, `related`, `placeLabel`, `fields[] {key, label, type,
options, unit, auto, required}`, `clocks` (names from the app's library), `verb`, `signatures`, **`subtypes`**,
`supersedes`. The schema is also written as a JSON Schema that CI validates every type file against (page 52, P0).

- **Three levels, one rule each** (page 48):
  - **item** (`item.yml`, built into the app): fields that mean the same for every type. These are title, acquired,
    price, place, story, **Signed** (by, dedication, date, proof photo) and **Bundle of** (`contains`: a list of works,
    so two or more makes a bundle). They stay hidden until the object has a value, and **+ Add** reveals them.
  - **type**: the hobby's nouns, as today.
  - **subtype**: one level only, keyed on platform for games and format for music and film. It inherits everything. It
    can add fields (a review is flagged past about 5), preset and hide a field (Saturn → media: disc), narrow a choice,
    add ladder parts, and name care clocks from the library. It can't remove or rename a parent field, add a signature
    or a clock kind, have subtypes, or change the object screen.
  - **Subtypes absorb `mediumRules`.** Music's vinyl, CD, cassette and other become subtypes (48 Q1 and Q2, leaning
    format).
- A **resolver** (`resolve(type, subtype) -> EffectiveType`) is the one function every screen and the import use. It
  is tested against Video games (5 subtypes, written from page 48) and Video Media (8, from `video-media.yml`).
- `TegolaCatalogue` decodes and **validates** each manifest: field keys are unique; kinds are known; a scale has at
  least two steps; `Missing` comes last if present; at most one verb and two signatures; clock names exist in the
  library; subtypes follow the rules above (PD-010, PD-015, PD-017, PD-019). An invalid manifest fails a test, never the
  app.
- **Clocks are a library the app owns** (page 52, P2): `drinkingWindow`, `mediaRot`, `discRot`, `saveBattery`,
  `serviceRisk` and so on, each a named, parameterised function over an object's events and fields. A type names the
  ones it uses and can't define its own. Every signal shows its reason and can be dismissed, and dismissals are logged
  (risk R2).
- **v1 enables Music, Books, Video games, Wine and Thing** (PD-164; Q10 asks whether a fifth real type joins). The
  rest ship as test fixtures, and enabling one is the release-train step (PD-111). Video Media is the candidate for the
  community's sixth type (51 Q3). No screen changes for a new type.
- Field kinds a type can use: `text`, `number`, `choice`, `yesNo`, `date`, `year`, `yearRange`, `event`, `list`,
  `log`, `photo`, `scale`. Kinds a collector can use for own fields: text, number, choice, yes/no, date, event, photo
  (PD-130).

### 3.4 Promises, as tests

These are the product's promises to a collector (clctn `CLAUDE.md`, SPEC "Testing Decisions"). Each one is a property
test over random `ShelfCommand` sequences, run once per v1 type:

1. No command overwrites a value the collector typed (lookups, enrichment, import, migration) (PD-045, PD-047).
2. No command merges two objects (PD-151).
3. History only grows; no command updates or deletes a history row (PD-051).
4. Wanted, borrowed and let-go objects never appear in counts, stats or the inventory document (PD-061, PD-070).
5. With the money switch off, no screen state contains a value, a paid figure on a share card, or a sell action
   (PD-080, PD-063). Paid is still recorded (story 165).
6. Quantity objects never offer Lend; a promoted copy does (PD-020, PD-121).
7. The app never writes `acquiredAt` (PD-165).
8. Nothing is confirmed without a collector action (PD-042).

---

## 4. Features

Each feature names the stories it covers (clctn SPEC numbers), what I'd change or read into them, and a "Done when".
Screens are the board ids in `docs/design/BOARDS.md`.

### 4.0 Visual rules every screen follows

These come from the handoff README ("high-fidelity; colours, typography, spacing, borders, shadows and copy are
final"), 00_Design System and 42_One Roof. The exact values are in `BOARDS.md` § Token table.

- **The printed-object look:** 2.5 pt ink borders (2 pt on small chips), hard offset shadows with no blur (3 pt for
  cards and chips, 4 pt for large cards, 5 pt for documents; orange instead of ink on dark surfaces), no gradient
  chrome. Halftone dots go only on colour fields and cover art.
- **Three typefaces, no exceptions.** Display is Bricolage Grotesque 800, Text is Archivo 400/600/700, Mono is DM Mono
  500 uppercase with 0.10–0.14 em tracking. Titles break across two lines on purpose ("My / Collections"). Text scales
  with Dynamic Type; display faces keep their optical size.
- **Not yours** (D27, PD-062): a dashed 2.5 pt `ruleDark` edge and **no shadow**, at every size, for wanted, borrowed
  and shared objects. It's one `notYours()` modifier in the design system, used everywhere. clctn had three different
  dashed styles. A dashed slot that *invites* ("+ Add a detail") uses the same dash, and the design system names both
  uses.
- **Status:** one chip from five swatches (fine · good · watch · act · gone), defined once as tokens.
- **Chrome:** inside a modal, the way out is **Close** or **Cancel**, never Back. Bottom sheets have a 24 pt top
  radius, a 46×5 grabber and a 0.28–0.32 ink backdrop. The tab bar's middle slot is a raised 40 pt scan button that
  presents. Every hit target is 44×44 or larger.
- **Copy** is final on the boards. The words come from the glossary, and PD-101's list is never used.
- **No 3D** (PD-145). The object hero is the collector's photo, or the type's flat hero (mark plus gradient plus
  halftone). The disc picker and sleeve rotation on board `item` are not built.
- **Boards are older than the decision log.** The prototype was drawn before the grilling rounds. Its tab bar reads
  SHELF · LENT · + · STATS · ME, money is on, and the object screen has four tabs, a "Sell it" button and a 3D
  sleeve. **The boards set how things look; the PD log sets what is there.** Where they disagree, for example the tab
  labels (PD-117), money off (PD-138), the seven slots instead of tabs (PD-013), and no selling (PD-135), I keep the
  board's visual language and follow the decision. `BOARDS.md` marks each disagreement on the board it affects, so a
  reviewer can see what changed and why.

### 4.1 v1 features

**F1 · Types (catalogue).** Stories 48–51, 55–61, 69–73, 82, 87. Five enabled types; condition with up to three axes on
one scale and "Missing" (Music's packaging follows the medium, ADR-0002); the spine relabelled per type; signatures
from the kit. *v1 signatures:* the **ladder** (condition axes) for every graded type, the **case** (bottles left) for
Wine, the **gauge** (drinking window) for Wine. *Done when* all 17 manifests decode and validate, and the five v1
types are the ones enabled.

**F2 · First piece and the empty shelf.** Stories 1–6, 9; PD-166, PD-137, PD-102, PD-165; page 46. Four screens:

1. **One question.** *Welcome to CLCTN · Show us something you love. Just one thing, the one with a story. Hold it
   up.* The camera is already live, with **Type it**, **Library** and **Just look around first**. There are no
   categories and no account.
2. **Recognise, then ask why.** The photo, the inferred type and name as a guess with **That's it** / **Not quite**.
   With nothing recognised, *What is it?* is a dashed field focused on arrival, and the button says why it's disabled
   (clctn journey 1's fault). Then *How did it come to you?*: one chip plus an optional line, which becomes the first
   log entry. It's never written to `acquiredAt` (PD-165).
3. **Type not shipped yet** (2B). *Watches aren't a full type yet. It's saved safely as a Thing.* **Count me in**
   records the collector as a tester for that type, so when the type ships, their pieces are offered the migration
   first (PD-031). **Not now** does nothing.
4. **The payoff, then momentum.** *Your shelf · 1 piece*: the piece's first signal or clock if it has one, and the
   story under it. Then empty slots with **One at a time** (the same camera) and **That's enough for today**. **Snap
   the whole shelf** is the sweep, so it's v1.x (roadmap); v1 doesn't show it.

Only the first piece is onboarding. Importing a list starts from Add (49 Q3), and the empty shelf offers **Scan your
first object** and **Bring your list**, which opens Add's import. There's no sample data. *Done when* a named piece
lands on the shelf in a collection the collector never created, with its story as the first history event and no
acquired date, and a piece of a type that isn't enabled is saved as a Thing with the tester offer.

**F3 · Shelf home.** Stories 147–153; PD-139, PD-140. From top to bottom: the header count (plus value only with money
on); a Today strip with non-empty lines only (*N to tidy*, *N need attention*, *N overdue*); a stats card; collections
as rows, with the same row shape for every type; the wishlist as a dashed collection; Places once two exist. The tab
bar is Shelf · Find · Scan · Activity · You. Shelf and Scan are fixed, and the middle slot presents rather than
navigates. *Done when* the Today strip shows exactly its non-empty lines and the screen matches board `home` with
money on and off.

**F4 · Collection and Object.** Stories 44–47, 52–54, 83–85. A collection lists its objects as rows (photo, or the
type's flat tile with mark and gradient), with a mono meta line (`128 RELEASES · 2 LENT`), sorting, filters by place
and status, and rename. A mixed collection groups by type. The object screen is a display case with seven slots in a
fixed order: hero, spine, status, signature, fields, actions, history (PD-013). Its only controls are actions: Edit,
Photo, Lend/Return, Let go, Might let go, plus the type verb. 3D is shelved (PD-145), so the hero is the photo, or the
type's flat hero when there's none. *Done when* every v1 type shows the seven slots in order.

**F5 · Edit form.** Stories 15, 25, 46, 55, 89; PD-050. A separate form with Save and Cancel, bound to the object's
`Draft`. Each field kind gets its control: steppers, chips, the hobby's real scale, year with "NV" for wine. Values a
lookup filled are badged **AUTO** until touched. A **Place** field takes a path, which fixes journey 1's fault 2.
**Add a detail** adds an own field (PD-130 kinds). Saving appends one `edited` event with the changed keys. *Done
when* Cancel writes nothing, and Save writes one history event that names exactly the changed keys.

**F6 · Adding: by hand, photo and barcode.** Stories 8–16, 23; PD-040, PD-041, PD-046, PD-118, PD-137. Capture →
propose → confirm → fill, the same for every type. The Scan tab presents the camera (live barcode and text through
VisionKit), with **Type it** always available. **Add to** defaults to the last-used collection and can be corrected
before shooting. The first object of a type creates its collection ("My Music"). After a shot, the camera **stays
open** and the new object goes to a tray, which fixes journey 1's fault 3. With no signal, objects save with what's
known and lookups queue. **Identify?** (sending the photo) is per shot and off by default, and in v1 it shows only if
an identification provider exists (Q3). *Done when* the first object of a type creates its collection, and Add to
remembers the last collection used.

**F7 · Match, "you already own this", look-alikes.** Stories 21, 22, 26, 27; PD-044, PD-151. Every match says,
unprompted, whether you already own it or another print of it, and lists related objects (the manifest's `related`
keys). A look-alike offers three choices: open the existing one, add another copy (raise the count on quantity
types), or add as new. It asks only when unsure. *Done when* no path merges, and the three choices are offered.

**F8 · Review queue and enrichment.** Stories 24, 28–33; PD-042, PD-045, PD-150. A grouped list, with runs of the same
object together. Each row says why it was guessed, with **Confirm** and **Fill in** on every row and **Confirm all**
when matches are strong. Unconfirmed objects count, show and are searchable. A late lookup offers to fill only empty
fields, and asks first. *Done when* Confirm all confirms only strong matches, and enrichment never touches a typed
field.

**F9 · Import.** Stories 34, 36–41, 43; PD-047, PD-048, PD-155; page 49. The test file is the real one:
`original-spec/uploads/Jeux collection.csv`, which has 485 games in a grid of 20 platform columns, semicolons,
French notes in cells ("cartouche + manuel", "boite endommagé", "doublon", "dédicace JDG"), typos and bundles.

- **Where it starts:** **Import a list** on the Add screen, next to the camera and typing (49 Q3), and the share sheet
  from Files, Mail or Numbers, which lands on the same screen. It accepts CSV, TSV and pasted text, nothing else.
- **Fast lane:** a file matching the published `clctn.csv` template (one row per object, fixed headers, the same
  format Export writes) imports instantly with no guessing. A Discogs CSV export is a second known shape.
- **Any other layout:**
  1. Read on the phone (encoding and separator sniffed).
  2. **Understand the shape:** the layout (a column per platform, no title header) maps headers to subtypes, picks the
     region from the locale and notes.
  3. **Extract each cell** into a typed object: parts and condition from the notes, signed, bundles split by "/",
     "doublon" as a second copy, digital kept apart. Anything it can't read goes into the note, untouched. It never
     invents a value.

  Steps 2 and 3 run on the device with Apple's Foundation Models, using guided generation into a `@Generable` struct
  mirroring the resolved type (49, "Mapping"), 20–30 cells per call. That's free, private and offline, so PD-047's
  "the file never leaves the phone" holds.
- **One sentence to confirm:** *485 video games on 20 platforms, into a collection called Jeux.* The collector can
  rename the collection there. **Build my shelf**, or **Something's off**, which opens the column mapper, the only
  escape hatch. The import creates **one collection** named after the file, and the platforms become shelves inside
  it, from the subtype (49 §06). Sheet tabs like "Vendu" or "Recherché" become statuses (let go, wanted), not
  collections.
- **Nothing is dropped** (49 Q2). Unknown rows land as written, with no match. Everything is unconfirmed (PD-042), and
  real ambiguities ("Which Tetris?") wait in an exceptions queue that's a badge, never a gate.
- **The payoff from their own notes:** *We noticed a few things while unpacking*: Imperfect (3), Duplicate (1), Signed
  (1), Series (3 of 4). These are live saved views (F11).
- **Matching titles to a database** (49's step 4) and cover art (step 5) need the backend, so they wait for Q9. In v1,
  covers are the collector's photos or the flat type tile.
- The batch can be undone for 30 days, keeping what the collector has since touched (D-12).

*Done when* `Jeux collection.csv` lands as one "Jeux" collection with a shelf per platform, every cell kept, notes
turned into parts, condition, signed and bundles as the 49 table shows, and undo removing the untouched objects.

**F10 · Places.** Stories 103–111; PD-053. A place is created by typing a path (`Cellar › Rack 3 › Bin 12`) on an
object, in a sweep tray, or in bulk "Move to…". Recent places come first. A place holds every type, and unplaced is
never a warning. The Places screen appears once two places exist. Near-duplicate names are caught and merge in one tap.
Collections filter by place, and Find searches by place. *Done when* typing a path creates nested places, and the
screen appears only at two.

**F11 · Find.** Stories 154–156, 187–194. Search over every field, note and entry (one track on an LP). Filters stack
as removable chips: type, bought in, condition, lent out, place, status, and archive included or not. Each result says
what matched. Everything runs on the phone, offline, and nothing searched leaves it. In a shop, the query
`artist / maker / series` shows what you own, what you let go and what you used up (stories 188–190).
**Saved views** (47, 49) are live queries, not copies:

- **Imperfect:** any ladder part at "missing" or "worn".
- **Duplicates.**
- **Signed:** by whom, from the item-level field.
- **Digital.**
- **Might let go.**
- **Also exists on:** the same work on other platforms or formats, grouped through `workID`, for "Doom on everything".

Series completion ("3 of 4 Ridge Racer") shows only what is owned, never an invented total (story 198).

*Done when* a single track is found, chips stack, each result names the field that matched, and the Imperfect view
lists exactly the objects with a missing or worn part.

**F12 · Stats.** Stories 85, 153; PD-159. With money off: counts; shape by decade, by the type's choice fields and by
type; shelf health (*31 have no photo*); lending habits. Grouped by type, never averaged across types. *Done when* a
mixed shelf shows per-type groups and no cross-type average.

**F13 · People and lending.** Stories 112–114, 119–126; PD-123, PD-146, PD-148, PD-160, PD-061. Lend in three taps:
type a name (recent first), optionally pick a due date (2 weeks, 1 month, a date) and add a note. The loan is
**closed by the collector** in v1, and the history says it was one-sided, because the borrower's page needs a backend
(PD-160). The return asks how it came back, and that goes into history. There's one reminder notification on the due
date. Overdue loans show in Today and in Activity. **Nudge** opens the share sheet with a friendly line and the object
card (there's no link to re-send in v1). Each Person has a page with what they hold now and a track record. Borrowed
objects have a dashed edge and are never counted. **Activity** gathers loans out, borrowed objects and overdue loans.
It's the only tab with a badge, and the badge is gone when nothing is due. The history names the person (journey 3's
open finding, D-3). *Done when* the door journey records, reminds and closes one-sided, with the person in the history.

**F14 · Sharing, one-sided.** Stories 128–131 (as cards), 133, 135; PD-063, PD-160. **Share the record** (public
facts) and **share my copy** (condition, photos, and an asking price only with money on) render a **share card**
image and open the share sheet. What was paid is never on a card. Share links, revoking (PD-158), the received-card
page and co-owned shelves need the backend and wait. A wishlist shares as a card list that reveals wants, never
holdings (PD-071). *Done when* no card, of either kind, with money on or off, contains what was paid.

**F15 · Quantity, wine and clocks.** Stories 66–73, 78–80; PD-020, PD-021, PD-121, PD-127, PD-017, PD-153. Quantity
objects show a count and **promote** one copy into its own object, which can be lent. Wine is consumable: **Open a
bottle** lowers the count and logs the pour (occasion, note, score). At zero the wine moves to **Drunk** and is kept.
The same wine with different provenance is a separate object. The drinking-window clock is always labelled
**Estimate**, feeds status and *need attention*, and its notifications are offered once, in plain words, when the
first clocked object is added. *Done when* the last bottle moves to Drunk and is still found by Find.

**F16 · Wanting and leaving.** Stories 137–146, 204; PD-070, PD-126, PD-149, PD-052. Wanted objects are ordinary
objects with ownership `wanted`, a priority and an optional price cap (the cap shows only with money on). They live
in the dashed wishlist inside Shelf. **It arrived** flips ownership, and the history stays intact. **Grail** marks
the ones that matter most. **Might let go** is a private flag, with a list of everything flagged. **Let go** takes a
reason (sold, gifted, traded, lost, broken), with a price only with money on, and moves the object to the archive,
which is searchable and answers *did I ever own this?* *Done when* a let-go object is out of every count, and a
search or a scan still finds it.

**F17 · You: settings, export, inventory, money, nudges.** Stories 7, 148, 159–169, 172–177; PD-080, PD-096,
PD-100, PD-154, PD-156, PD-161, PD-162.

- **Settings:** the money switch (off), always identify (off), nudge tone (Dry/Plain/Off) and language (English and
  French; grading terms such as VG+, MNH and CIB are never translated).
- **Tab editor:** reorders Find and Activity / You around the fixed Shelf and Scan, and never hides a feature.
- **Export:** CSV and JSON with photos, in the import template's shape.
- **Inventory document:** a dated PDF with photo, condition, provenance, place and price paid. It says plainly that
  it isn't an appraisal. Market values are added only with money on, and there are no values in v1 (PD-138).
- **Nudges:** at most one a week, only about a named unfinished thing, and none when the queue is empty.
- **Analytics:** shape-only events (the archive's `05_Tagging and Metrics` taxonomy, trimmed to v1, with
  `object_flagged_sellable` and `wish_added` included), stored locally.
- **Debug screen:** a hidden screen shows the events, the settings in force and the database counts (PD-162).

*Done when* export → import gives back the same shelf, the inventory document says it is not an appraisal, and money
off shows no value on any screen.

### 4.2 What I read into the stories (decisions to log as D-1 …)

| D | Question | Reading |
|---|---|---|
| D-1 | Which archive is the original spec | `original-spec/` in this repo. Its September pages match `clctn/design/` byte for byte; the October pages are reconciled as §0 row 15 says |
| D-2 | Loans without a backend | Every loan is closed by the collector; the borrower can't confirm, and the screen says so (PD-160) |
| D-3 | History of a loan doesn't say to whom (journey 3 finding) | `lent` and `returned` events carry the person's id and name at the time |
| D-4 | Camera throws you out after every shot (journey 1 fault 3) | The camera stays open, and new objects collect in a tray |
| D-5 | No place field in the edit form (journey 1 fault 2) | The edit form has a Place field (F5) |
| D-6 | Nudge with no link | The share sheet with a friendly line and the object card |
| D-7 | Value fields with money off | Paid is recorded and editable, never totalled; value and price cap are hidden (stories 161, 165) |
| D-8 | Runs and sets (stories 195–206) | v1 shows series and "also exists on" from owned objects only, through the work layer (47); it never invents a total (#23). Declaring a run, its gaps and "finished" are not in v1 |
| D-9 | Analytics destination with no backend | Local only, visible in the debug screen; no network |
| D-10 | Dark mode | The designed palette only; dark "stage" surfaces where the boards have them (Q5) |
| D-11 | Token values disagree | The archive's handoff table wins over both implementations: muted is `#6E6458` (clctn has `#5A5045`); teal `#12A594` is a type tint and green `#0E6E5E` means money (the-collection calls `#0E6E5E` "teal"). Six manifests use gradient keys the palette lacks (claret, verdigris, phosphor, oxide, indigo, plum); they get tokens, taken from the archive's type pages. |
| D-12 | Import undo after the collector has changed things | Undo removes the batch's objects that nobody touched since the import. Objects that were edited, photographed, lent or placed are kept, and the summary says "3 kept because you changed them". clctn hard-deleted them, which destroys work (PD-090's spirit). |
| D-13 | "It arrived" on a wanted object | The object moves from the wishlist to its type's collection (created if needed), and history records `owned`. clctn left it in the wishlist. |
| D-14 | Imported rows and `acquired` | An import writes `added` only. It writes `acquired` only from a column the mapping assigns to it, and dates the event, not the field, as the collector's own fact (PD-165). |
| D-16 | October pages vs the PD log | The October refinements are adopted where they don't contradict a confirmed decision; where they do (backend, accounts and subscription, marketplace payments), the PD log holds in v1 until Q9 is answered (§0 row 15) |
| D-17 | Event log or mutable rows | Both: the log is the truth, and the rows are a projection written in the same transaction and rebuildable from it (§3.1). clctn's ADR-0006/0007 rows and JSON fields stay as the projection's shape |
| D-18 | Video games' `mediaRules` (43) vs subtypes (48) | Subtypes keyed on platform replace `mediaRules`; music's per-format rules become format subtypes (48 Q1, Q2 leanings). `video-game.yml` gains the 5 subtypes page 48 draws |
| D-19 | Consoles | Not a subtype of Video games; hardware is its own type, linked to the games it runs (47 D1, 48 Q4). Not in v1 |
| D-20 | `playStatus` (47 ask 05) | `video-game.yml` gains `playStatus` (not started / playing / finished / abandoned), replacing `playLog`'s finished flag. Its "started long ago, never finished" clock is opt-in |
| D-21 | Import grouping | One collection per file, platforms as shelves inside it from the subtype, sheet tabs as statuses (49 §06). If a video-game collection exists, the confirm sentence offers to add to it instead; that's a choice the collector makes, so PD-151's never-merge holds |
| D-22 | Digital games in an import | Kept, as `media: digital`, in the Digital view (49), and never counted as physical objects in stats, since the catalogue is physical (PD-024) |
| D-15 | Status mapping (five swatches) | It is derived in `TegolaModel` from 42_One Roof's rules, not in views. `unconfirmed` reads "To tidy" (clctn showed "Out"), `lent` reads "Out", overdue and needs details read "Needs you". |

### 4.3 Not in v1

Taken from the roadmap; each waits for the reason it gives:

- **v1.x:** sweep capture; clocks for other types; custom types, "no type fits" routes beyond Thing, and fields added
  to an official type; the type board; migration; iPad and Mac; more import connectors; co-owned shelf; parts (Add
  part).
- **Needs a backend (PD-160):** loan links, share links and revoking, the received-card page, the borrower's
  confirmation, the shared wishlist page, gift-taking (stories 180–186).
- **v2 / v3:** values, receipts, value alerts, wishlist hits, the insurance export with values, the payment shape, the
  offer index.
- **Shelved:** 3D, inspect and annotate, photo vs drawing (S1), pro mode, profiles, the listening list.

### 4.4 Journeys, as UI tests

From clctn's `docs/product/journeys/`, rewritten for tegola's v1. Each runs from a cold launch with `--reset`:

1. **The first evening:** first piece, then a second typed by hand, a photo added later, and a place set.
2. **Bring your list:** empty shelf → Bring your list → `Jeux collection.csv` (handed in by a `--import-fixture`
   launch argument, because a fresh simulator has no file to pick, with recorded model outputs) → *485 video games on
   20 platforms, into a collection called Jeux* → Build my shelf → *We noticed a few things* → the Imperfect view.
3. **Lend at the door:** object → Lend → "Dara" → due in 2 weeks → overdue on a moved clock → Return → history.
4. **Saturday in the shop:** Find "Blue Note" → owned, let go and wanted shown together → make one wanted in one tap.
5. **The weekly glance:** Today strip → *1 needs attention* → a wine at its peak → Open a bottle.
6. **Letting go and the insurer's email:** Might let go list → Let go (sold) → archive → You → Inventory document.

Camera beats can't run on a simulator, where `DataScannerViewController.isSupported` is false. `ScannerClient` has a
scripted test value, so the journeys feed it what the camera "saw" instead of stopping.

---

## 5. TCA tree

```
AppFeature (root)
├─ launch: LaunchFeature               runs pending schema migrations once, before the shelf opens (ADR-0008)
├─ @Presents firstPiece: FirstPieceFeature
├─ selectedTab, tabOrder (@Shared(.settings))
├─ shelf:    ShelfFeature        + shelfPath:    StackState<Path.State>
├─ find:     FindFeature         + findPath:     StackState<Path.State>
├─ activity: ActivityFeature     + activityPath: StackState<Path.State>
├─ you:      YouFeature          + youPath:      StackState<Path.State>
├─ @Presents capture: CaptureFeature   (the Scan slot presents)
│   ├─ @Presents match: MatchFeature   (you already own this, related, look-alike choice)
│   └─ @Presents addByHand: AddByHandFeature
└─ @Presents importFlow: ImportFeature (sources → mapping → running → summary)

@Reducer enum Path                     one enum for every tab's stack, defined in AppFeature
  collection(CollectionFeature) · object(ObjectFeature) · place(PlaceFeature) · places(PlacesFeature)
  person(PersonFeature) · stats(StatsFeature) · reviewQueue(ReviewQueueFeature) · archive(ArchiveFeature)
  wishlist(WishlistFeature) · mightLetGo(MightLetGoFeature) · settings(SettingsFeature)
  tabEditor(TabEditorFeature) · export(ExportFeature) · inventory(InventoryFeature) · debug(DebugFeature)

ObjectFeature
└─ @Presents destination: Destination
     edit(ObjectEditFeature) · lend(LendFeature) · returnLoan(ReturnFeature) · letGo(LetGoFeature)
     promote(PromoteFeature) · openBottle(OpenBottleFeature) · share(ShareFeature)
     enrichment(EnrichmentFeature) · photo(PhotoPickerFeature)
```

- **Navigation goes up as a delegate.** A feature asks for a screen with `.delegate(.open(Route))`: `Route` is a
  small enum in `TegolaModel` (`.object(id)`, `.person(id)`, …). Only `AppFeature` pushes. This is how features stay
  independent of each other (ADR-0005), and it is telaio's "children send delegates up, only the root mutates" rule
  applied to navigation.
- **Deep links and launch arguments** (`--screen <name>`) map to the same `Route`, so a UI flow test opens exactly what
  a user would.
- **Children read their own queries.** No feature receives a copy of another's data. Each holds the `@FetchAll` it
  needs, keyed by ids it was given.
- **Cancellable effects:** `CancelID.search`, `.lookup(objectID)`, `.import(batchID)`, `.scanner`.

| Client | Live value | Test / preview value |
|---|---|---|
| `ShelfClient` | `perform(ShelfCommand)` over SQLiteData, in `TegolaStorage` | the same, on an in-memory database with the seed |
| `CatalogueClient` | the bundled manifests | the same (pure); fixtures for the twelve disabled types |
| `LookupClient` | MusicBrainz (music barcodes) and Open Library (ISBN) over `URLSession`, ephemeral session | recorded payloads from `TegolaTestSupport`; `unimplemented` by default |
| `IdentifyClient` | none in v1 unless Q3 says otherwise | scripted |
| `ExtractionClient` | Foundation Models (`LanguageModelSession`, guided generation into `@Generable` types built from the resolved type) for import shape and cell extraction, and for inferring the first piece's type; on devices without Apple Intelligence it falls back to the column mapper and keeps cells as notes | recorded outputs per fixture cell; `unimplemented` by default |
| `ScannerClient` | VisionKit `DataScannerViewController` (barcodes, text) | an `AsyncStream` driven by the test |
| `PhotoStoreClient` | files in Application Support, thumbnails | an in-memory store |
| `ShareCardClient` | `ImageRenderer` of the card view | records calls |
| `PDFClient` | `UIGraphicsPDFRenderer` | records calls; the page model is tested in `TegolaInterchange` |
| `FileImportClient` / `FileExportClient` | document picker, `ShareLink` files | fixture files |
| `NotificationsClient` | `UNUserNotificationCenter` (loan due, clock offer, weekly nudge) | records schedule calls |
| `ReachabilityClient` | `NWPathMonitor` | a controllable stream |
| `AnalyticsClient` | the local analytics database | records events |
| built-ins | `continuousClock`, `date`, `uuid`, `locale`, `calendar` | `TestClock`, `.constant`, `.incrementing`, fixed `en`/`fr` |

Persisted settings use `@Shared`. Collector settings (money, always identify, tone, language, tab order, last-used
collection) are rows in the `settings` table, read through a custom `SharedKey`, so they sync with the shelf later
(PD-161). Purely local UI state (the last Find chips) uses `.appStorage`.

---

## 6. Privacy, files, CI

**Privacy.**

- No account, no server copy of the shelf (ADR-0001, PD-094).
- Network calls are lookups only: a barcode, an ISBN or OCR text goes out, and never a photo except through Identify
  (PD-118).
- Logs and analytics record shape only (PD-095).
- `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` say exactly that.

**Files.** Photos are files in Application Support, referenced by `photos.fileName`. Exports are written to a temporary
directory and handed to the share sheet, and the import file is read in place and never copied.

**CI.**

- `.github/workflows/ci.yml` has two jobs:
  - **`linux-core`** runs on every push and PR: `scripts/test-linux.sh` on `ubuntu-latest` with the Swift 6.x Linux
    toolchain (the newest version available on hosted runners). It builds and tests the three pure packages and runs
    the guard tests. It's free.
  - **`macos`** runs only by `workflow_dispatch`, as in telaio: `scripts/ci.sh` on `macos-26` with Xcode 26.6 (iOS 26
    SDK). It checks the iOS 26 build path.
- Everything else runs on the Mac (Xcode 27.1). `scripts/test.sh` runs only what changed, and `scripts/ci.sh` runs the
  full gate before each milestone merge. Every PR includes the summary.
- `scripts/secret-scan.sh` runs in both jobs and on the Mac.

---

## 7. Lookup and the queue

Lookups are the only network path in v1.

- A captured identifier goes into `lookupQueue` with the object, so it is saved before any network.
- A worker effect drains the queue when `ReachabilityClient` says it's online: oldest first, exponential backoff, at
  most 5 attempts, then the row goes to "needs details".
- A result never writes. It creates an **enrichment proposal** that the review queue or the object screen shows, and
  applying it is a `ShelfCommand.applyEnrichment` that only fills empty fields (PD-045). Filled fields are marked
  `auto` until touched.
- Providers per v1 type: Music → MusicBrainz (barcode); Books → Open Library (ISBN); Video games, Wine, Thing → none
  (OCR text proposes a title only). Discogs' API needs a token, so it isn't a v1 lookup source, and the Discogs
  *import* uses the collector's CSV export instead (Q3).

---

## 8. Reuse from the legacy code

Nothing is copied as is. What I'd port, after review against this plan:

| From | What | Why |
|---|---|---|
| clctn `Sources/TypeCatalogue/Types/*.yml` | the 17 manifests, unchanged | They're data, already reviewed, and validated by F1's test |
| clctn `docs/product/journeys/` | the beats and their verdicts | The walking order is already worked out; §4.4 rewrites them for tegola |
| clctn `TestSupport.Seed` (shape) | the 116-object seed shelf | Previews and tests see the same shelf |
| clctn `docs/engineering/pointfree.md` | the SQLiteData rules already learned the hard way | Fewer repeat mistakes |
| the archive `15_CSV Format`, `49_Import Pipeline` §03B | the `clctn.csv` template and the conversion prompt | Story 42; the import's fast lane and Export's format |
| `original-spec/uploads/Jeux collection.csv` | the import fixture, as is | A real file from a real collector, which beats an invented one |
| `original-spec/video-media.yml`, page 48's Video games subtypes | the subtype fixtures | M2's exit test |
| the archive `05_Tagging and Metrics` | the event taxonomy | F17 analytics |
| the-collection `CollectorKit/Resources/Fonts` | the three OFL fonts and their licences | The faces the boards use |
| the-collection `CollectorKit` (`TypeStyle`, `hardShadow`, `dashedSlot`, `halftone`, `FlowRow`) | the techniques, rewritten against tegola's tokens | They already reproduce the printed look in SwiftUI; the values come from the archive, not from it |

What I'd **not** carry: clctn's generated `Package.swift` (PackageGeneratorPlugin) and XcodeGen project (telaio uses a
hand-written, minimal project and hand-written manifests), swift-configuration, SwiftFormat and the git hook, and
the-collection's `Navigator`/`StackHost` (TCA `StackState` replaces it).

---

## 9. How I'll work after you approve

1. **Plan.** `tasks/plan.md` and `tasks/todo.md`, broken down by milestone with the `planning-and-task-breakdown`
   skill. Each task has acceptance criteria, a verify step and its files.
2. **Branches.** One integration branch per milestone, `m<n>/<module-id>`, and one branch per task, `m<n>/<task-slug>`,
   each with one PR into the milestone branch, as in telaio. In this cloud session I can only push
   `claude/tegola-rearchitecture-jcq29f`, so until you say otherwise I stack each milestone's work there as one commit
   per task, and open one PR per milestone (Q7).
3. **Review.** A separate review agent, which doesn't see my reasoning, reviews each milestone against this plan
   before it's marked ready.
4. **Milestone end.** `docs/milestones/M<n>.md` lists what works, what doesn't, the tests and their results (marked
   *Mac* or *Linux*), and snapshot PNGs.
5. **Spec changes.** A question that comes up mid-task gets a `D-` number in `docs/DECISIONS.md`, and the task
   carries on with that reading. A change to a `PD-` decision or to v1 scope waits for you.

---

## 10. Questions

Each has the default I'll use if you don't answer.

1. ~~**The original spec.**~~ Answered: `original-spec/` is in the repo (§0 row 1).
2. **Name.** Code and bundle id use `Tegola` / `fr.macko.tegola`. What do collectors see: **Tegola** or **CLCTN**
   (PD-157 was only assumed)? *Default: Tegola.*
3. **Lookups and Identify without a backend.** v1 can call MusicBrainz and Open Library directly from the phone. The
   Discogs API needs a token, and Identify (photo matching) needs a vision service that doesn't exist yet. *Default:
   MusicBrainz and Open Library only; Identify hidden in v1; Discogs is import-only.*
4. **iCloud sync.** It's not in the confirmed v1 list. *Default: the schema is CloudKit-ready, and sync is not
   switched on in v1.*
5. **Dark mode.** The design is one printed-paper palette with dark "stage" screens. *Default: no system dark mode in
   v1; screens follow their boards.*
6. **Verification.** This container has no Xcode. I can build and test the pure packages here (Linux toolchain) and
   write everything else, but "zero warnings in Swift 6 mode" and the TestStore, snapshot and UI tests for the app need
   your Mac (or a paid manual `macos-26` run). *Default: each milestone PR says which checks ran where, and app-level
   checks are marked "needs a Mac run".*
7. **Branches.** One branch per task (telaio's way) needs push rights to new branches, and this session can push only
   to `claude/tegola-rearchitecture-jcq29f`. *Default: one commit per task on that branch, one draft PR per
   milestone.*
8. **Contrast vs fidelity.** The archive's meta grey on paper (3.34:1), and paper text on orange, teal and pink
   (2.6–3.3:1), fail WCAG AA at the sizes the boards use. *Default: keep every fill colour, and add derived text tokens
   that pass, as telaio does (`metaText`, a darker grey at 4.5:1 or above; ink text instead of paper text on orange,
   teal and pink). Each change is listed in BOARDS.md next to the board it alters.*
9. **The October pages vs confirmed decisions.** Pages 49, 50 and 52 assume a backend in v1, for title matching
   against game databases (IGDB, ScreenScraper, Wikidata) and cover art on a CDN. They also put accounts, sync and a
   €50/year subscription plus the €29.99 unlock in v1's last phase (P5). That contradicts PD-160 (no backend in v1),
   ADR-0001 (no account) and PD-112/113 (payment shape decided after launch). *Default: v1 stays backend-free and
   account-free. The import extracts on the device and keeps unmatched titles as written. Matching and covers arrive
   with the first backend, and P5 is planned after M9.* If you want the backend in v1, it becomes its own module
   (`backend`, before M6) with its own spec.
10. **Launch types.** PD-164 says five types *including* Thing (Music, Books, Video games, Wine, Thing). Pages 40 and
    51 say "five types + Thing", with Retro computers suggested for the fifth slot. *Default: PD-164's list. Retro
    computers is the first type on the release train.*
11. **Discogs import** (found while rendering board 16). Its board signs in to Discogs, which needs a backend. *Default:
    the CSV file Discogs lets you export, as a known shape in the fast lane.*
12. **Shelf layout** (boards `home` and `collection`). The boards show a grid of tiles; PLAN F3 and F4, from PD-139,
    say rows. *Default: the boards' tiles and their visual language on Shelf, rows inside a collection.*

## 11. Milestone 1 deliverables (after approval)

- [ ] `tasks/plan.md` and `tasks/todo.md` by milestone; `tasks/HANDOFF.md`; `tasks/briefs/agent-brief.md` and
  `teststore-brief.md`
- [ ] `.swift-format`, `.periphery.yml`, `.gitignore`, `CLAUDE.md`, `README.md`
- [ ] The seven packages with empty feature targets that compile, and one smoke test each (a `TestStore` smoke test
  in each feature target)
- [ ] `Tegola.xcodeproj`: app, `TegolaTests` and `TegolaUITests`, which launches to an empty root on iOS 26 and 27
- [ ] `TegolaDesignSystem/Tokens/` with every token from the boards, the three fonts registered, and a contrast test
  for every text/background pair at 4.5:1 or above (or each exception named, with the reason)
- [ ] The guard tests (§2.5)
- [ ] `scripts/test.sh`, `ci.sh`, `test-linux.sh`, `secret-scan.sh`, `periphery.sh`; `.github/workflows/ci.yml`
  (`linux-core` automatic, `macos` manual)
- [ ] `TegolaTestSupport`: `Jeux collection.csv` with recorded extraction outputs, a `clctn.csv` template file, a
  Discogs export, recorded MusicBrainz and Open Library payloads (the seed shelf lives in `TegolaStorage`, §2.4)
- [ ] `docs/GLOSSARY.md`, `docs/DECISIONS.md` (D-1 to D-22), `docs/testing/ui-tests.md`

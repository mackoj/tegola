# UI tests

**Policy.** A check is a UI test only when it needs the running app: that a screen is reachable at all, that a system
sheet or the camera hand-off works, that focus and keyboard behave. Everything else is a `TestStore` test or a package
test, which are faster and run on every change. UI tests run at the milestone gate (`scripts/ci.sh`) and on request
(`scripts/test.sh ui`), never on every change.

Every UI test launches with `--reset` (an empty catalogue), plus `--seed` where the sitting starts with a shelf, or
`--screen <name>` for a flow test about one screen. The journeys never use `--screen`: half of what a journey proves
is that the screen can be reached (clctn's journeys found three faults that way).

| UI test | Why it needs the app | Since |
|---|---|---|
| `AppShellUITests.testEveryTabIsReachableAndScanPresents` | the tab bar's buttons exist and Scan presents a sheet | M1 |

The six journeys of PLAN §4.4 join as their screens are built (M3 to M8).

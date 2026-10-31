#!/usr/bin/env bash
# The pure core, on any machine with a Swift toolchain (Linux CI, cloud agents, or the Mac):
# the packages that import no Apple UI framework, plus the design tokens and the guard tests.
#   scripts/test-linux.sh                 # every pure package
#   scripts/test-linux.sh TegolaModel     # one package
# Writes build/test-linux-summary.md. Uses `swift` from PATH (on the Mac, prefer scripts/test.sh, which uses xcrun).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p build
SUMMARY=build/test-linux-summary.md
echo "# Linux core ($(date '+%Y-%m-%d %H:%M'), $(swift --version 2>&1 | head -1))" > "$SUMMARY"
STATUS=0
# TegolaDesignSystem is listed for its TegolaDesignTokens target only; its SwiftUI target is skipped off Apple
# platforms by `#if canImport(SwiftUI)`.
# Swift Testing prints one "Test run with N tests in M suites passed" line per test bundle; sum them (as test.sh does).
package_totals() { # $1 log
  grep -Eo 'Test run with [0-9]+ tests? in [0-9]+ suites? passed' "$1" |
    awk '{ tests += $4; suites += $7; runs += 1 }
      END { printf "%d tests in %d suites passed (%d test run%s)", tests, suites, runs, (runs == 1 ? "" : "s") }'
}
PACKAGES=(TegolaTestSupport TegolaCatalogue TegolaModel TegolaInterchange TegolaLookupAPI TegolaDesignSystem)
[[ $# -ge 1 ]] && PACKAGES=("$@")
for pkg in "${PACKAGES[@]}"; do
  log="build/linux-$pkg.log"
  echo "▶ $pkg"
  if swift test --package-path "Packages/$pkg" >"$log" 2>&1; then
    echo "- ✅ \`$pkg\` — $(package_totals "$log")" >> "$SUMMARY"
  else
    STATUS=1
    echo "- ❌ \`$pkg\` — see $log" >> "$SUMMARY"
    grep -E "error:|✘|failed" "$log" | head -20 | sed 's/^/    /' >> "$SUMMARY"
  fi
done
cat "$SUMMARY"
exit $STATUS

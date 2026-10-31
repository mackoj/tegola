#!/usr/bin/env bash
# Full local gate on the Mac, run before a milestone merges into main: every package's tests, the app's unit
# tests and every UI test (the journeys, docs/testing/ui-tests.md), swift-format lint, the API lint, secret scan.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
STATUS=0
for pkg in TegolaDesignSystem TegolaTestSupport TegolaCatalogue TegolaModel TegolaInterchange TegolaLookupAPI TegolaStorage TegolaFeatures; do
  scripts/test.sh "$pkg" || STATUS=1
  cp build/test-summary.md "build/summary-$pkg.md"
done
if [[ -d Tegola.xcodeproj ]]; then
  scripts/test.sh app || STATUS=1
  cp build/test-summary.md build/summary-app.md
fi
{
  echo "# CI summary ($(date '+%Y-%m-%d %H:%M'), $(xcodebuild -version | head -1), $(sw_vers -productVersion))"
  cat build/summary-*.md | grep -E "^- "
  echo
  if xcrun swift-format lint --strict --recursive Packages/*/Sources Packages/*/Tests Tegola TegolaTests TegolaUITests 2>build/lint.log; then echo "- ✅ swift-format lint"; else STATUS=1; echo "- ❌ swift-format lint ($(wc -l < build/lint.log) findings, see build/lint.log)"; fi
  if scripts/lint-api.sh >build/lint-api.log 2>&1; then echo "- ✅ API lint"; else STATUS=1; echo "- ❌ API lint (see build/lint-api.log)"; fi
  if scripts/secret-scan.sh >build/secret-scan.log 2>&1; then echo "- ✅ secret scan"; else STATUS=1; echo "- ❌ secret scan (see build/secret-scan.log)"; fi
} > build/ci-summary.md
cat build/ci-summary.md
exit $STATUS

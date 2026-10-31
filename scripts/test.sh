#!/usr/bin/env bash
# Focused tests: runs only the packages / feature targets touched since the base branch.
#   scripts/test.sh                       # auto-detect from git diff against $BASE (default: the branch it forked from)
#   scripts/test.sh TegolaModel           # one package
#   scripts/test.sh TegolaFeatures CanvasFeatureTests   # one test target (swift test --filter)
#   scripts/test.sh app                   # xcodebuild test for the app, unit + UI tests (iPhone 17 simulator)
#   scripts/test.sh app-unit              # the app's unit tests only (TegolaTests)
#   scripts/test.sh ui                    # the UI tests only (TegolaUITests: the journeys, docs/testing/ui-tests.md)
# Without arguments, the app's unit tests run (no UI tests) when Tegola/, TegolaTests/, TegolaUITests/,
# Tegola.xcodeproj/ or Packages/TegolaFeatures/ changed. UI tests run at the milestone gate (scripts/ci.sh) and on
# request (`ui`, `app`).
# $BASE defaults to the nearest of origin/main and the origin/m<N>/* branches (see default_base). Override with
# BASE=<ref>. When nothing changed since the base, the summary says no tests ran.
# Writes build/test-summary.md. Always uses Xcode's toolchain (xcrun), never swiftly's. On Linux, use
# scripts/test-linux.sh instead.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p build
SUMMARY=build/test-summary.md
echo "# Test summary ($(date '+%Y-%m-%d %H:%M'), $(xcodebuild -version | head -1))" > "$SUMMARY"
STATUS=0

# A short digest of a failing log: xcsift (https://github.com/ldomaradzki/xcsift) when installed, else grep.
digest() {
  if command -v xcsift >/dev/null; then
    xcsift --format toon < "$1" 2>/dev/null | head -40 | sed 's/^/    /'
  else
    grep -E "error:|✘|failed" "$1" | head -20 | sed 's/^/    /'
  fi
}

# Swift Testing prints one "Test run with N tests in M suites passed" line per test bundle; a package with several
# test targets (TegolaFeatures) has several. Report their sum.
package_totals() { # $1 log
  grep -Eo 'Test run with [0-9]+ tests? in [0-9]+ suites? passed( after [0-9.]+ seconds)?( with [0-9]+ known issues?)?' "$1" |
    awk '{ tests += $4; suites += $7; runs += 1; if ($0 ~ /known issue/) { n = $0; sub(/.* with /, "", n); known += n + 0 } }
      END { printf "%d tests in %d suites passed (%d test run%s)%s", tests, suites, runs, (runs == 1 ? "" : "s"),
        (known ? sprintf(", %d known issue%s", known, (known == 1 ? "" : "s")) : "") }'
}

run_package() { # $1 package, $2 optional filter
  local pkg="$1" filter="${2:-}" log="build/test-$1${2:+-$2}.log"
  # A package listed for a later milestone (TegolaStorage before M2, D-31) is skipped until it exists.
  [[ -f "Packages/$pkg/Package.swift" ]] || { echo "- ⏭️ \`$pkg\` doesn't exist yet" >> "$SUMMARY"; return 0; }
  echo "▶ $pkg ${filter:+($filter)}"
  if xcrun swift test --package-path "Packages/$pkg" ${filter:+--filter "$filter"} >"$log" 2>&1; then
    echo "- ✅ \`$pkg\` ${filter:+\`$filter\`} — $(package_totals "$log")" >> "$SUMMARY"
  else
    STATUS=1
    echo "- ❌ \`$pkg\` ${filter:+\`$filter\`} — see $log" >> "$SUMMARY"
    digest "$log" >> "$SUMMARY"
  fi
}

# UI tests drive the real screen, keyboard and mouse, so only one xcodebuild test of the app may run on this Mac at a
# time (several agents share the machine). The lock is a directory (mkdir is atomic); a stale lock left by a dead
# process is taken over.
LOCK_DIR="${TMPDIR:-/tmp}/tegola-app-tests.lock"
acquire_app_lock() {
  local waited=0
  until mkdir "$LOCK_DIR" 2>/dev/null; do
    local holder
    holder=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
    if [[ -n "$holder" ]] && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$LOCK_DIR"
      continue
    fi
    if (( waited % 60 == 0 )); then echo "… waiting for another app test run (pid ${holder:-?}) to finish"; fi
    sleep 5
    waited=$((waited + 5))
  done
  echo $$ > "$LOCK_DIR/pid"
  trap 'rm -rf "$LOCK_DIR"' EXIT
}

# The newest available iPhone simulator, unless DESTINATION says otherwise: simulator names change with each Xcode, so
# none is hard-coded.
default_destination() {
  local id
  id=$(xcrun simctl list devices available -j 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(next(x['udid'] for r in sorted(d, reverse=True) if 'iOS' in r for x in d[r] if x['name'].startswith('iPhone')))" 2>/dev/null)
  if [[ -n "$id" ]]; then echo "platform=iOS Simulator,id=$id"; else echo "platform=iOS Simulator,name=iPhone 17"; fi
}

run_app() {
  acquire_app_lock
  echo "▶ app (xcodebuild test${ONLY_TESTING:+, only $ONLY_TESTING})"
  local log=build/test-app.log result="build/Tegola-$(date +%s).xcresult"
  # -testLanguage en: the app has a French localization; its tests read English on a Mac set to French.
  xcodebuild test -project Tegola.xcodeproj -scheme Tegola -destination "${DESTINATION:-$(default_destination)}" -testLanguage en \
    -derivedDataPath build/DerivedData -resultBundlePath "$result" \
    ${ONLY_TESTING:+-only-testing:"$ONLY_TESTING"} >"$log" 2>&1
  local code=$?
  local line
  line=$(xcrun xcresulttool get test-results summary --path "$result" 2>/dev/null | python3 scripts/xcresult-summary.py 2>/dev/null)
  [[ -z "$line" ]] && line="no test results: the build or package resolution failed"
  if [[ $code -eq 0 ]]; then
    echo "- ✅ app — $line" >> "$SUMMARY"
  else
    STATUS=1
    echo "- ❌ app — $line (see $log, $result)" >> "$SUMMARY"
    digest "$log" >> "$SUMMARY"
  fi
}

# The branch HEAD forked from: of origin/main and the origin/m<N>/* branches, the one whose merge base with HEAD has
# the fewest commits up to HEAD. Skipped: this branch's own remote (origin/<branch>), and branches already ahead of HEAD
# (stacked on it), except origin/main (HEAD is on main) and a branch at HEAD itself on a named branch (a new task branch
# with no commit yet). On a detached HEAD, a branch at HEAD is the one checked out, not the fork point, so it is
# skipped. The upstream is not skipped: a task branch's upstream is usually its milestone branch, the fork point. So a
# local branch named differently from its remote finds its own remote, and only its unpushed commits count as changed
# (none: the summary says no tests ran). Keep one name for the local and remote branch, or pass BASE=origin/m<N>/<name>
# of the milestone branch. Prints the branch name, or HEAD when there is none (no remote branches).
default_base() {
  local current own head ref mb count best="" best_count=""
  current=$(git branch --show-current 2>/dev/null || true)
  own="origin/$current"
  head=$(git rev-parse HEAD 2>/dev/null) || { echo HEAD; return 0; }
  for ref in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin/main 'refs/remotes/origin/m[0-9]*/*'); do
    [[ "$ref" == "$own" ]] && continue
    if [[ "$(git rev-parse "$ref")" == "$head" ]]; then
      [[ -n "$current" ]] || continue
      count=0
    elif git merge-base --is-ancestor HEAD "$ref"; then
      [[ "$ref" == origin/main ]] || continue
      count=0
    else
      mb=$(git merge-base HEAD "$ref" 2>/dev/null) || continue
      count=$(git rev-list --count "$mb..HEAD")
    fi
    if [[ -z "$best_count" ]] || ((count < best_count)); then
      best="$ref"
      best_count="$count"
    fi
  done
  echo "${best:-HEAD}"
}

if [[ $# -ge 1 ]]; then
  case "$1" in
    app) run_app ;;
    app-unit) ONLY_TESTING=TegolaTests run_app ;;
    ui) ONLY_TESTING=TegolaUITests run_app ;;
    *) run_package "$1" "${2:-}" ;;
  esac
else
  BASE="${BASE:-$(default_base)}"
  echo "Base: \`$BASE\` ($(git rev-parse --short "$BASE" 2>/dev/null || echo "unknown"))" >> "$SUMMARY"
  CHANGED=$(git diff --name-only "$BASE"...HEAD; git diff --name-only; git ls-files --others --exclude-standard)
  declare -a TARGETS=()
  for pkg in TegolaDesignSystem TegolaTestSupport TegolaCatalogue TegolaModel TegolaInterchange TegolaLookupAPI TegolaStorage; do
    grep -q "^Packages/$pkg/" <<<"$CHANGED" && TARGETS+=("$pkg")
  done
  # api/ is TegolaLookupAPI's input.
  grep -q "^api/" <<<"$CHANGED" && TARGETS+=(TegolaLookupAPI)
  # Upstream packages changed => their dependents must re-test too (PLAN §2.4 graph).
  [[ " ${TARGETS[*]-} " =~ " TegolaCatalogue " ]] && TARGETS+=(TegolaModel TegolaInterchange TegolaStorage)
  [[ " ${TARGETS[*]-} " =~ " TegolaModel " ]] && TARGETS+=(TegolaInterchange TegolaStorage)
  for pkg in $(printf '%s\n' "${TARGETS[@]-}" | awk 'NF && !seen[$0]++'); do run_package "$pkg"; done
  # TegolaFeatures: per changed target, or everything if the manifest or a shared target changed.
  FEAT=$(grep -E "^Packages/TegolaFeatures/" <<<"$CHANGED" || true)
  if [[ -n "$FEAT" || ${#TARGETS[@]} -gt 0 ]]; then
    if grep -qE "Package.swift|/Tests/FeatureTestSupport/" <<<"$FEAT" || [[ ${#TARGETS[@]} -gt 0 && -z "$FEAT" ]]; then
      run_package TegolaFeatures
    else
      for t in $(grep -Eo "^Packages/TegolaFeatures/(Sources|Tests)/[A-Za-z]+/" <<<"$FEAT" | sed -E 's#^Packages/TegolaFeatures/(Sources|Tests)/##; s#/$##; s#Tests$##' | sort -u); do
        run_package TegolaFeatures "${t}Tests"
      done
    fi
  fi
  if grep -qE "^(Tegola/|TegolaUITests/|Tegola.xcodeproj/|TegolaTests/|Packages/TegolaFeatures/)" <<<"$CHANGED"; then
    # The app's unit tests, without the screen. The UI suite waits for the milestone gate.
    ONLY_TESTING=TegolaTests run_app
  fi
  # A summary with no result line must not pass for a green run.
  grep -q '^- ' "$SUMMARY" || echo "- ⚠️ nothing changed since \`$BASE\`: no tests ran" >> "$SUMMARY"
fi
cat "$SUMMARY"
exit $STATUS

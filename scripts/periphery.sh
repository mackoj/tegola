#!/usr/bin/env bash
# Dead-code search with periphery (`brew install periphery`), built with Xcode's toolchain.
#   scripts/periphery.sh                 # scan with .periphery.yml, results in build/periphery.txt
#   scripts/periphery.sh --format json   # extra arguments go to `periphery scan`
# periphery calls `swift` and `xcodebuild` from PATH. The `swift` on PATH here is swiftly's open-source toolchain,
# which breaks swift-snapshot-testing, so Xcode's toolchain directory goes first on PATH and TOOLCHAINS is cleared.
# The report lists findings; it never edits code. Removing dead code is a separate, reviewed change.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if ! command -v periphery >/dev/null; then
  echo "periphery isn't installed: brew install periphery" >&2
  exit 1
fi
XCODE_TOOLCHAIN_BIN="$(dirname "$(xcrun --find swift)")"
export PATH="$XCODE_TOOLCHAIN_BIN:$PATH"
unset TOOLCHAINS
if [[ "$(command -v swift)" != "$XCODE_TOOLCHAIN_BIN/swift" ]]; then
  echo "swift isn't Xcode's ($(command -v swift))" >&2
  exit 1
fi
mkdir -p build
echo "periphery $(periphery version), $(xcodebuild -version | head -1), swift: $(command -v swift)" >&2
periphery scan --config .periphery.yml --disable-update-check --write-results build/periphery.txt "$@"

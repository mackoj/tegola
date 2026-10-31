#!/usr/bin/env bash
# Extract strings into the Localizable.xcstrings catalogs, as an Xcode build does in the IDE (command-line
# builds don't). Run it on the milestone branch at each wave, and before a PR that adds UI text; then commit
# the changed catalogs. The exported .xcloc bundle itself is thrown away.
# Then every key of every catalog gets an entry for each language in TRANSLATIONS, state `new` (the English text
# stands in) until it is translated (scripts/xcstrings-add-language.py, T15.1; how to translate:
# docs/i18n/fr-glossary.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
if ! xcodebuild -exportLocalizations -project Tegola.xcodeproj -scheme Tegola -localizationPath "$OUT" \
  -exportLanguage en -derivedDataPath build/DerivedData >build/sync-strings.log 2>&1; then
  echo "❌ exportLocalizations failed, see build/sync-strings.log"
  exit 1
fi
TRANSLATIONS=(fr)
CATALOGS=()
while IFS= read -r f; do CATALOGS+=("$f"); done < <(find Tegola Packages -name '*.xcstrings' -not -path '*/.build/*' | sort)
for language in "${TRANSLATIONS[@]}"; do
  python3 scripts/xcstrings-add-language.py "$language" "${CATALOGS[@]}" >/dev/null
done
CHANGED="$(git status --porcelain -- '*.xcstrings' | awk '{print $2}')"
for f in $CHANGED; do
  python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$f" || { echo "❌ invalid JSON: $f"; exit 1; }
done
if [[ -z "$CHANGED" ]]; then echo "✅ string catalogs already up to date"; else echo "✅ updated:"; echo "$CHANGED"; fi

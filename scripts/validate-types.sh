#!/usr/bin/env bash
# Checks every bundled type file against schema/type.schema.json (page 52, P0). Needs Node (npx); the version is
# pinned so an ajv release can't change what "valid" means without a commit. The Swift decoder is the other check:
# TegolaCatalogue's tests decode and validate the same files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
npx --yes ajv-cli@5.0.0 validate --spec=draft2020 --strict=false --all-errors \
  -s schema/type.schema.json -d "Packages/TegolaCatalogue/Sources/TegolaCatalogue/Types/*.yml"

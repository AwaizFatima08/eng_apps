#!/usr/bin/env bash
# Release gate (plan §3): analyze + every worked case must pass, else no build.
# Usage: tool/release_check.sh apps/instrument_toolkit
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:?app folder, e.g. apps/instrument_toolkit}"
(cd "$root/packages/plant_core" && flutter analyze && flutter test)
(cd "$root/$app" && flutter analyze && flutter test)
echo "RELEASE CHECK: PASS ($app)"

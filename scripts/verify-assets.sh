#!/usr/bin/env bash
# Verify the integrity of everything under vendor/ and the presence of the vendored tools.
#   scripts/verify-assets.sh [--deep]     --deep also gunzips each ocr binary and checks the upstream sha256sum.txt
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEEP=0; [ "${1:-}" = "--deep" ] && DEEP=1
fail=0
check() { # dir sumfile
  ( cd "$1" && if command -v sha256sum >/dev/null 2>&1; then sha256sum -c --quiet "$2"; else shasum -a 256 -c "$2" >/dev/null; fi ) \
    && echo "ok    $1/$2" || { echo "FAIL  $1/$2"; fail=1; }
}
check_upstream() { # dir sumfile (upstream file listing more platforms than we vendor)
  ( cd "$1" && if command -v sha256sum >/dev/null 2>&1; then sha256sum -c --ignore-missing --quiet "$2"; else shasum -a 256 -c --ignore-missing "$2" >/dev/null; fi ) \
    && echo "ok    $1/$2 (vendored subset)" || { echo "FAIL  $1/$2"; fail=1; }
}
check "$ROOT/vendor/binaries/open-code-review" SHA256SUMS-gz.txt
check "$ROOT/vendor/binaries/reviewdog" SHA256SUMS.txt
check_upstream "$ROOT/vendor/binaries/reviewdog" checksums.txt
check "$ROOT/vendor/wheels/pr-agent" SHA256SUMS.txt
if [ $DEEP -eq 1 ]; then
  d="$ROOT/vendor/binaries/open-code-review"; tmp="$(mktemp -d)"
  for gz in "$d"/opencodereview-*.gz; do gunzip -c "$gz" > "$tmp/$(basename "${gz%.gz}")"; done
  cp "$d/sha256sum.txt" "$tmp/"
  ( cd "$tmp" && if command -v sha256sum >/dev/null 2>&1; then sha256sum -c --ignore-missing --quiet sha256sum.txt; else shasum -a 256 -c --ignore-missing sha256sum.txt >/dev/null; fi ) \
    && echo "ok    uncompressed ocr binaries match upstream sha256sum.txt" || { echo "FAIL  uncompressed ocr binaries"; fail=1; }
  rm -rf "$tmp"
fi
for t in open-code-review ponytail pr-agent reviewdog; do
  if [ -f "$ROOT/tools/$t/LICENSE" ]; then echo "ok    tools/$t (LICENSE present)"; else echo "FAIL  tools/$t missing or without LICENSE"; fail=1; fi
done
[ -f "$ROOT/vendor/wheels/pr-agent/requirements.lock.txt" ] && echo "ok    wheels lockfile ($(grep -c '==' "$ROOT/vendor/wheels/pr-agent/requirements.lock.txt") pins, $(ls "$ROOT/vendor/wheels/pr-agent"/*.whl | wc -l | tr -d ' ') wheels)"
exit $fail

#!/usr/bin/env bash
# ONLINE-SIDE script: re-vendor the four upstream projects into tools/ (verbatim, without .git).
#   scripts/sync-upstream.sh [--latest] [--only NAME] [--ref NAME=REF ...]
#     default: clone each tool at the tag recorded in vendor/MANIFEST.json
#     --latest        clone the default branch head instead
#     --only NAME     sync just one tool (open-code-review | ponytail | pr-agent | reviewdog)
#     --ref NAME=REF  pin a tool to a tag/branch/commit for this run
# After syncing it prints the new commits/tags; update vendor/MANIFEST.json and THIRD_PARTY_NOTICES.md,
# then run scripts/fetch-offline-assets.sh to refresh matching binaries/wheels.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/vendor/MANIFEST.json"
LATEST=0; ONLY=""; declare -A REFS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --latest) LATEST=1; shift ;;
    --only) ONLY="$2"; shift 2 ;;
    --ref) REFS["${2%%=*}"]="${2#*=}"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
field() { awk -v n="$1" -v k="$2" '$0 ~ "\"name\": \""n"\"" {f=1} f && $0 ~ "\""k"\":" {sub(/^[^:]*: */,""); gsub(/[",]/,""); print; exit}' "$MANIFEST"; }
TMP="$ROOT/.sync-tmp"; rm -rf "$TMP"; mkdir -p "$TMP"
for name in open-code-review ponytail pr-agent reviewdog; do
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue
  url="$(field "$name" upstream)"; ref="${REFS[$name]:-}"
  [ -z "$ref" ] && [ $LATEST -eq 0 ] && ref="$(field "$name" tag)"
  echo "==> $name  $url ${ref:+@ $ref}"
  git clone -q "$url" "$TMP/$name"
  [ -n "$ref" ] && git -C "$TMP/$name" checkout -q "$ref"
  rsync -a --delete --exclude .git "$TMP/$name/" "$ROOT/tools/$name/"
  printf '    commit %s  tag %s  date %s\n' "$(git -C "$TMP/$name" rev-parse HEAD)" "$(git -C "$TMP/$name" describe --tags --abbrev=0 2>/dev/null || echo -)" "$(git -C "$TMP/$name" log -1 --format=%cI)"
done
rm -rf "$TMP"
echo "done. Update vendor/MANIFEST.json + THIRD_PARTY_NOTICES.md with the lines above, then: git status"

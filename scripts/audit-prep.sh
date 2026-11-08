#!/usr/bin/env bash
# Whole-repository audit, deterministic layer. Produces everything a reviewing agent needs and a brief
# telling it what to do; the audit itself (REVIEW.md) is written by the agent (see skills/ccra-audit).
#
#   ccra audit [REPO] [--out DIR] [--no-lint] [--select RULES]
#     REPO            repository root (default: the git repo of the current directory)
#     --out DIR       output directory (default: <repo>/.ccra-review)
#     --no-lint       skip the ruff/reviewdog layer
#     --select RULES  ruff rule selection (default E,F,W,B,S,PLE,PLW; E501 is always ignored)
# Outputs: meta.json, lint-ruff.sarif, lint-ruff.txt, lint-ruff-concise.txt, lint-ruff-stats.txt,
#          ocr-delegate-preview.json, ocr-rule-groups.json, AUDIT-BRIEF.md
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CCRA_HOME="${CCRA_HOME:-$ROOT/.ccra}"
OCR="$CCRA_HOME/bin/ocr"; RD="$CCRA_HOME/bin/reviewdog"
export OCR_NO_UPDATE=1
REPO="" OUT="" LINT=1 SEL="E,F,W,B,S,PLE,PLW"
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --no-lint) LINT=0; shift ;;
    --select) SEL="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    -*) echo "audit: unknown option $1" >&2; exit 2 ;;
    *) REPO="$1"; shift ;;
  esac
done
REPO="$(git -C "${REPO:-.}" rev-parse --show-toplevel 2>/dev/null)" || { echo "audit: not a git repository" >&2; exit 1; }
OUT="${OUT:-$REPO/.ccra-review}"; mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
NAME="$(basename "$REPO")"

# ruff: venv copy (vendored), then PATH, then uvx (online only)
RUFF=""
if [ -x "$CCRA_HOME/venv/bin/ruff" ]; then RUFF="$CCRA_HOME/venv/bin/ruff"
elif command -v ruff >/dev/null 2>&1; then RUFF="ruff"
elif command -v uvx >/dev/null 2>&1; then RUFF="uvx ruff"; fi

head=$(git -C "$REPO" rev-parse HEAD); root=$(git -C "$REPO" rev-list --max-parents=0 HEAD | tail -1)
branch=$(git -C "$REPO" branch --show-current); hdate=$(git -C "$REPO" log -1 --format=%cI)
nfiles=$(git -C "$REPO" ls-files | wc -l | tr -d ' '); npy=$(git -C "$REPO" ls-files '*.py' | wc -l | tr -d ' ')
nloc=$(git -C "$REPO" ls-files '*.py' | (cd "$REPO" && xargs cat 2>/dev/null) | wc -l | tr -d ' ')
ntests=$(git -C "$REPO" ls-files 'tests/*' 'test/*' '*test_*.py' '*_test.py' | sort -u | wc -l | tr -d ' ')
echo "==> $NAME @ ${head:0:7} ($branch)  ->  $OUT"
cat > "$OUT/meta.json" <<JSON
{
  "repo": "$REPO",
  "name": "$NAME",
  "branch": "$branch",
  "head": "$head",
  "head_date": "$hdate",
  "root_commit": "$root",
  "tracked_files": $nfiles,
  "python_files": $npy,
  "python_loc": $nloc,
  "test_files": $ntests,
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tools": {
    "ccra": "$(cat "$ROOT/VERSION")",
    "ocr": "$([ -x "$OCR" ] && "$OCR" --version 2>/dev/null | head -1 || echo "not installed")",
    "reviewdog": "$([ -x "$RD" ] && "$RD" -version 2>/dev/null || echo "not installed")",
    "ruff": "$([ -n "$RUFF" ] && $RUFF --version 2>/dev/null || echo "not available")",
    "ruff_select": "$SEL (ignore E501)",
    "ai_review": "ocr delegate mode: file selection and rule groups by ocr; the review is performed by the host agent following ponytail-audit (skills/ccra-audit)"
  }
}
JSON

if [ $LINT -eq 1 ] && [ -n "$RUFF" ]; then
  ( cd "$REPO" && $RUFF check . --no-cache --select "$SEL" --ignore E501 --output-format sarif > "$OUT/lint-ruff.sarif" 2> "$OUT/lint-ruff.err" )
  ( cd "$REPO" && $RUFF check . --no-cache --select "$SEL" --ignore E501 --output-format concise > "$OUT/lint-ruff-concise.txt" 2>>"$OUT/lint-ruff.err" )
  ( cd "$REPO" && $RUFF check . --no-cache --select "$SEL" --ignore E501 --statistics > "$OUT/lint-ruff-stats.txt" 2>>"$OUT/lint-ruff.err" )
  if [ -x "$RD" ]; then
    ( cd "$REPO" && "$RD" -f=sarif -reporter=local -filter-mode=nofilter < "$OUT/lint-ruff.sarif" > "$OUT/lint-ruff.txt" 2>>"$OUT/lint-ruff.err" )
  fi
  echo "    lint: $(grep -c . "$OUT/lint-ruff-concise.txt" 2>/dev/null || echo 0) ruff findings ($SEL)"
else
  [ $LINT -eq 1 ] && echo "    lint: skipped (ruff not available: run ccra install, or put ruff on PATH)"
fi

if [ -x "$OCR" ]; then
  ( cd "$REPO" && "$OCR" delegate preview --format json --from "$root" --to HEAD > "$OUT/ocr-delegate-preview.json" 2> "$OUT/ocr.err" )
  ( cd "$REPO" && git ls-files '*.py' '*.js' '*.ts' '*.go' '*.java' '*.rb' '*.rs' '*.sh' '*.sql' '*.yaml' '*.yml' | xargs "$OCR" delegate rule --format json > "$OUT/ocr-rule-groups.json" 2>>"$OUT/ocr.err" )
  echo "    ocr:  $(sed -n 's/.*"reviewable_count": *\([0-9]*\).*/\1/p' "$OUT/ocr-delegate-preview.json") reviewable, $(sed -n 's/.*"excluded_count": *\([0-9]*\).*/\1/p' "$OUT/ocr-delegate-preview.json") excluded, $(grep -c '"group_id"' "$OUT/ocr-rule-groups.json") rule group(s)"
else
  echo "    ocr:  skipped (not installed: run ccra install)"
fi
find "$OUT" -name '*.err' -size 0 -delete 2>/dev/null

cat > "$OUT/AUDIT-BRIEF.md" <<MD
# Audit brief: $NAME

Repository (read-only): $REPO
Commit: $head ($branch, $hdate)
Output directory: $OUT
Write the report to: $OUT/REVIEW.md

You are the review engine of comprehensive-code-reviewer-agent in delegate mode. The deterministic
layer is already here: meta.json, ocr-delegate-preview.json (reviewable files from the root commit
to HEAD, plus exclusions; files from the root commit are in scope too, use \`git -C "$REPO" ls-files\`),
ocr-rule-groups.json (per-file checklist), lint-ruff-*.txt (leads to verify, not findings to copy).

Follow $ROOT/skills/ccra-audit/SKILL.md, which applies
$ROOT/tools/ponytail/skills/ponytail-audit/SKILL.md to this repository and fixes the report format.
Change no code in the repository. Reply with the Verdict line, the must/should/nice counts and the
coverage rate.
MD
echo "    brief: $OUT/AUDIT-BRIEF.md"
echo "Next: in Claude Code run  /ccra-audit $REPO --out $OUT   (or hand AUDIT-BRIEF.md to any coding agent)."

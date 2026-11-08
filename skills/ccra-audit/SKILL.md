---
name: ccra-audit
description: >
  Whole-repository code audit with the comprehensive-code-reviewer-agent (ccra) tool chain:
  open-code-review (ocr) in delegate mode selects files and attaches review rules, ruff through
  reviewdog adds a lint layer, and you perform the review following ponytail-audit and write
  REVIEW.md. Use for "audit this repo", "review the whole codebase", "run the code reviewer on
  <path>", "code review of <repo>", /ccra-audit [path] [--out DIR] (Copilot CLI: /ccra:ccra-audit).
---

# ccra-audit: whole-repository code review

Arguments: an optional repository path (default: the git repository you are in) and an optional
`--out DIR` (default: `<repo>/.ccra-review`). This is a report. Change no code in the repository
and create no files inside it except under the output directory.

## Finding the tool

Use the `ccra` command. It is on PATH after `scripts/install.sh --prefix ~/.local/bin`. If it is
not, use the checkout's `bin/ccra`: inside Claude Code that is `${CLAUDE_PLUGIN_ROOT}/bin/ccra`,
inside GitHub Copilot CLI `${PLUGIN_ROOT}/bin/ccra`; otherwise ask the user where the
comprehensive-code-reviewer-agent checkout is. `ccra root` prints the checkout path; the bundled
ponytail procedures are at `$(ccra root)/tools/ponytail/skills/`. If `ccra doctor` says ocr or
reviewdog is not installed, run `ccra install` once (offline, from vendored assets).

## 1. Deterministic layer

```bash
ccra audit <repo> --out <out>
```

This writes into `<out>`: `meta.json` (commit, sizes, tool versions), `lint-ruff-concise.txt`,
`lint-ruff.txt`, `lint-ruff-stats.txt`, `lint-ruff.sarif` (ruff rules E,F,W,B,S,PLE,PLW rendered
through reviewdog), `ocr-delegate-preview.json` (ocr's reviewable files from the root commit to
HEAD, plus exclusions), `ocr-rule-groups.json` (the review checklist ocr attaches to each file) and
`AUDIT-BRIEF.md`. If ruff or ocr is unavailable the script says so; continue without that layer.

## 2. Review

Read `$(ccra root)/tools/ponytail/skills/ponytail-audit/SKILL.md` and follow it exactly:
map first (README, build and deploy config, dependencies, entry points, tests, expected load),
trace the main flows end to end, then look for bugs, risks, scale problems, missing tests, speed and
lean. Every finding needs a concrete case. At most 20 findings. Plain English.

Use these inputs:
- `ocr-rule-groups.json` is the per-file checklist (correctness, security, performance,
  maintainability, test coverage).
- `ocr-delegate-preview.json` lists what ocr considers reviewable and what it excluded and why.
  Files created in the root commit are not listed but are in scope: `git ls-files` is the full
  inventory.
- Lint findings are leads to verify, never findings to copy. Fold the real ones (bugs, genuine
  security hits, undefined or unused names that reveal dead or broken code) into your findings.
- A fork or vendored copy of a public library: find the internal modifications and the
  integration layer and review those; say that you skipped unchanged upstream code.
- A big repository: go deep where a mistake costs the most (data loading, money, auth, writes,
  user input), not file by file. Say which parts you did not read.

## 3. Write `<out>/REVIEW.md`

```
# Code review: <repo name>

| | |
|---|---|
| Repository | <path> |
| Commit | <sha> (<branch>, <date>) |
| Reviewed | <YYYY-MM-DD> |
| Tool chain | comprehensive-code-reviewer-agent (ccra <version>): ocr delegate mode, reviewdog + ruff, review performed by <agent> following ponytail-audit |
| Size | <files> files, <python files> Python files, <lines> lines, <test files> test files |

## Audit
<the ponytail-audit report: "What this repo does:" and the assumed load; Must fix / Should fix /
Nice to have with findings numbered across groups, each with What this is / Problem / Fix /
If we skip it and a path:Lstart-end location; then Verdict:, Lean:, Not checked:>

## Coverage
Total files in scope (git ls-files): N. Read in full: N. Skimmed: N. Not read: N (which and why).
Coverage rate: X%. ocr delegate preview: N reviewable, N excluded.

## Lint layer (ruff via reviewdog)
Total findings: N. Top rules. Which lint hits were real and folded into findings above (by
number); why the rest are noise.
```

## 4. Reply

The Verdict line, the must/should/nice counts, the coverage rate and the path to the report.

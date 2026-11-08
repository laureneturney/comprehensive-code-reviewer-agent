---
name: ccra-review
description: >
  Review a change (working tree, branch range or single commit) with the
  comprehensive-code-reviewer-agent (ccra) tool chain. With an LLM configured for ocr it runs
  `ccra review` and verifies the findings; otherwise it runs ocr in delegate mode and you review
  the diff yourself following ponytail-review. Use for "review my changes", "review this branch
  against main", "review commit X", "review this PR", /ccra-review [--from A --to B | --commit SHA]
  (Copilot CLI: /ccra:ccra-review).
---

# ccra-review: review a change

Run from the root of the repository under review. Review only; change no code unless the user
also asked you to fix.

## Finding the tool

Use the `ccra` command. It is on PATH after `scripts/install.sh --prefix ~/.local/bin`. If it is
not, use the checkout's `bin/ccra`: inside Claude Code that is `${CLAUDE_PLUGIN_ROOT}/bin/ccra`,
inside GitHub Copilot CLI `${PLUGIN_ROOT}/bin/ccra`; otherwise ask the user where the
comprehensive-code-reviewer-agent checkout is. `ccra root` prints the checkout path; the bundled
ponytail procedures are at `$(ccra root)/tools/ponytail/skills/`. If `ccra doctor` says ocr or
reviewdog is not installed, run `ccra install` once (offline, from vendored assets).
Run `ccra doctor` first.

## Path A: ocr has an LLM configured (`ccra doctor` shows "ocr LLM: ... configured")

```bash
ccra review [--from A --to B | --commit SHA] --reporter local [--pr-url URL]
```

Findings land in `.ccra-review/ocr.sarif` and are printed through reviewdog. Read the code behind
every critical or high finding and confirm or drop it before presenting; group the rest by severity.

## Path B: delegate mode (no LLM endpoint for ocr)

1. `ccra ocr delegate preview --format json [--from A --to B | --commit SHA]`: the reviewable
   files, their status and the mode (workspace, range with merge_base, commit).
2. `ccra ocr delegate rule --format json <paths...>`: the checklist per file group.
3. Diffs, plain and uncoloured:
   - range: `git --no-pager diff --no-ext-diff --no-textconv --no-color <merge_base>..<to> -- "<path>"`
   - commit: `git --no-pager show --no-ext-diff --no-textconv --no-color <commit> -- "<path>"`
   - workspace: `git --no-pager diff --no-ext-diff --no-textconv --no-color HEAD -- "<path>"`;
     untracked files are read whole.
4. Review every reviewable file against its rule group, following
   `$(ccra root)/tools/ponytail/skills/ponytail-review/SKILL.md`: read the diff, then the
   code it touches (callers, callees, tests), trace the real flow, and look for bugs, risk, scale,
   missing tests, speed and lean. Mark each file reviewed or skipped with a reason. Do not stop at
   the first high-severity issue.

## Output (both paths)

Findings in three groups, numbered across groups: **Must fix** (bug, security, data loss, breaks
at expected load), **Should fix** (risky code without a test, real slowness, duplication, mixed
jobs, code that should not exist), **Nice to have**. Each finding: `path:Lstart-end`, **What this
is**, **Problem** (a concrete case), **Fix** (smallest that works), **If we skip it**. End with
`Verdict:` and a coverage line: total files, reviewed, skipped (with reasons).

If the user asked to fix as well: apply Must fix items directly, describe Should fix items that
need a human decision, skip Nice to have unless trivial.

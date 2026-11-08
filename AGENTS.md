# comprehensive-code-reviewer-agent (ccra)

An offline bundle of four code-review tools (open-code-review, pr-agent, reviewdog, ponytail) with
one front door, `bin/ccra`. Everything installs from the vendored assets in this repository; no
network is needed at install or run time except the LLM endpoint and git host you point it at.

## Calling the reviewer

| You want | Run |
|----------|-----|
| Install once | `scripts/install.sh --prefix ~/.local/bin` then `ccra doctor` |
| Review a change from the terminal | `ccra review [--from main --to HEAD \| --commit SHA] [--reporter local\|gitlab-mr-discussion\|github-pr-review] [--pr-url URL]` |
| Audit a whole repository from the terminal | `ccra audit <repo> --out <dir>` (deterministic layer + a brief for the agent that writes the audit) |
| Classic linters into an MR/PR | `ccra lint -reporter=gitlab-mr-discussion` |
| Use it inside Claude Code | `ccra agents claude` (or `/plugin marketplace add <this repo path>` then `/plugin install ccra@ccra`), then `/ccra-audit [path]`, `/ccra-review [range]`, or ask for the `code-reviewer` agent |
| Use it inside GitHub Copilot CLI | `ccra agents copilot` (or `copilot plugin marketplace add <this repo path>` then `copilot plugin install ccra@ccra`), then `/ccra:ccra-audit`, `/ccra:ccra-review` |
| Use it inside Copilot in VS Code or the Copilot coding agent | `ccra agents skills <project>/.github/skills` and `ccra agents agents-md <project>`; `ccra` must be on PATH |
| Use it inside Codex, Cursor, OpenCode | `ccra agents codex \| cursor \| opencode` prints or applies the steps |
| Any agent that reads skills | `ccra agents skills <dir>` copies the ccra, ponytail and ocr skills into `<dir>` |

The agent-side entry points are `skills/ccra-audit/SKILL.md`, `skills/ccra-review/SKILL.md` and
`agents/code-reviewer.md`. They run ocr in delegate mode (no LLM endpoint needed on the ocr side)
and follow ponytail's review and audit procedures from `tools/ponytail/skills/`.

## Rules for agents working on this repository

- Never edit anything under `tools/`: those are verbatim upstream copies, kept byte-identical so a
  sync is a plain overwrite. Integration code lives in `bin/`, `scripts/`, `config/`, `skills/`,
  `agents/`, `docs/`.
- Keep it offline-safe: no download, package install or update check in `bin/ccra`,
  `scripts/install.sh` or the skills. Online-side work goes in `scripts/fetch-offline-assets.sh`
  and `scripts/sync-upstream.sh`.
- After touching `vendor/`, run `scripts/verify-assets.sh --deep` and update `vendor/MANIFEST.json`.
- `bash -n` every shell script you change; `scripts/install.sh --force && bin/ccra doctor` is the smoke test.

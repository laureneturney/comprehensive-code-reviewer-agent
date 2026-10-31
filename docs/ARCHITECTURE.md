# Architecture: how the four tools fit together

Each bundled project covers a different layer of code review. `ccra` (bin/ccra) wires them
into one pipeline but never hides them: every tool is still callable on its own.

| Layer | Tool | What it does | Needs an LLM? |
|-------|------|--------------|---------------|
| Transport | **reviewdog** | Takes any linter output (errorformat, checkstyle, SARIF, rdjson) and posts it where reviewers look: terminal, GitLab MR discussions, GitHub PR reviews/checks, Bitbucket. Filters findings to the diff. | No |
| Diff-level AI review | **open-code-review (ocr)** | Deterministic file selection, bundling and rule matching, then an LLM agent reviews each bundle with repo-search tools. Outputs text, JSON or SARIF. Has a *delegate* mode where a coding agent does the reviewing and ocr only supplies the plan. | Yes, or a host agent in delegate mode |
| PR/MR-level AI assistant | **pr-agent** | `/review`, `/describe`, `/improve`, `/ask`, `/update_changelog` on a hosted MR/PR, or on a local branch pair (writes `review.md`). Talks to any model through LiteLLM. | Yes |
| Agent behaviour | **ponytail** | Rules and skills for coding agents (Claude Code, Codex, Cursor, OpenCode, Gemini CLI, ...): write the smallest correct change, plus `/ponytail-review` and `/ponytail-audit` reports. | Uses the agent's own model |

## The `ccra review` pipeline

```
 repo under review (run from its root)
        │
        ├─ ocr review --format sarif ──────────▶ .ccra-review/ocr.sarif
        │                                              │
        │                                   reviewdog -f=sarif -reporter=…
        │                                              │
        │                       ┌──────────────────────┼─────────────────────────┐
        │                   local (terminal)   gitlab-mr-discussion      github-pr-review
        │
        └─ pr-agent review ──▶ MR/PR summary comment (--pr-url)  or  ./review.md (--local-target BRANCH)

 ccra lint:   ruff / eslint / golangci-lint / shellcheck / … ──▶ reviewdog ──▶ same reporters

 inside a coding agent (Claude Code, Codex, Cursor, …):
     /ponytail-review   /ponytail-audit   /open-code-review:review   /open-code-review:delegate-review
```

Why SARIF in the middle: ocr already emits SARIF 2.1.0 and reviewdog consumes it, so ocr's
findings land as inline MR/PR discussions without any custom glue. The same path works for
every classic linter via `ccra lint`.

## Where state lives

| Item | Location | Committed? |
|------|----------|------------|
| Installed binaries, venv, env file | `.ccra/` (override with `CCRA_HOME`) | No |
| ocr provider/model config | `~/.opencodereview/` | No |
| pr-agent settings | env vars `SECTION__KEY`, or `.pr_agent.toml` in the reviewed repo, or `tools/pr-agent/pr_agent/settings/.secrets.toml` (git-ignored) | No |
| reviewdog runners | `config/reviewdog.yml`, or `.reviewdog.yml` in the reviewed repo | Yes |
| ocr project rules | `.opencodereview/rule.json` in the reviewed repo | In that repo |
| Review outputs | `.ccra-review/` in the reviewed repo | No |

## Offline design

Nothing in `ccra install` or `ccra <tool>` touches the network:

- Go tools ship as official release binaries under `vendor/binaries/`, checksum-verified against the upstream checksum files at install time.
- pr-agent's exact dependency set (from its `uv.lock`) is a wheelhouse under `vendor/wheels/pr-agent/`; `pip install --no-index` builds the venv.
- `ccra` exports `OCR_NO_UPDATE=1`, `LITELLM_LOCAL_MODEL_COST_MAP=True` and `HF_HUB_OFFLINE=1`, and pr-agent points tiktoken at the encodings bundled inside litellm, so no tool phones home at import or start-up.
- ponytail is plain Markdown/JS and installs from the local checkout path.

The only network the tools need at *run* time is whatever you point them at: your LLM endpoint and your GitLab/GitHub instance.

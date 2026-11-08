# Usage

All commands assume `bin/ccra` is on PATH (or use the full path). Run review commands from
the root of the repository you are reviewing.

## Everyday commands

```bash
ccra doctor                                   # what is installed / configured
ccra review                                   # AI review of uncommitted changes, printed locally
ccra review --from main --to HEAD             # review a branch against main
ccra review --commit abc123                   # review one commit
ccra review --from main --to HEAD --local-target main      # + pr-agent review.md, no hosting token needed
ccra review --reporter gitlab-mr-discussion --pr-url https://gitlab.example.com/g/p/-/merge_requests/42
ccra lint -reporter=local -diff="git diff main"            # classic linters through reviewdog
ccra audit ~/src/foo --out ~/code-reviews/foo              # whole-repo audit: deterministic layer + AUDIT-BRIEF.md
```

## Inside a coding agent (delegate mode, no LLM endpoint needed)

```bash
ccra agents claude      # registers this repo, ponytail and open-code-review as local plugin marketplaces
```
Then in Claude Code: `/ccra-audit [path] [--out DIR]` audits a whole repository and writes
`REVIEW.md`; `/ccra-review [--from A --to B | --commit SHA]` reviews a change; "use the
code-reviewer agent on <path>" runs the same procedure as a subagent. The skills live in
`skills/ccra-audit/SKILL.md` and `skills/ccra-review/SKILL.md`; the agent in `agents/code-reviewer.md`.
Each report folder gets `meta.json`, `lint-ruff-*.txt`, `ocr-delegate-preview.json`,
`ocr-rule-groups.json`, `AUDIT-BRIEF.md` and the `REVIEW.md` the agent writes.

`ccra audit` alone (no agent) still produces everything except `REVIEW.md`; hand `AUDIT-BRIEF.md`
to any coding agent to finish.

Everything after `--` goes to `ocr review` unchanged, e.g.
`ccra review -- --background-file docs/requirements.md --exclude '**/generated/**'`.

## open-code-review (ocr)

```bash
ccra ocr review                    # workspace changes
ccra ocr review --from main --to feature --format json --output result.json
ccra ocr scan --path src/payments  # whole files, no diff needed
ccra ocr review --preview          # which files would be reviewed
ccra ocr rules                     # inspect matched rules
ccra ocr delegate preview --format json      # plan only; a coding agent performs the review
ccra ocr config provider | model   # interactive LLM setup -> ~/.opencodereview/config.json
ccra ocr llm test
```
LLM via env instead of the config file: `OCR_LLM_URL`, `OCR_LLM_TOKEN`, `OCR_LLM_MODEL`,
`OCR_LLM_PROTOCOL` (`openai` | `anthropic`), `OCR_LLM_TIMEOUT`; `ANTHROPIC_BASE_URL` /
`ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_MODEL` are honoured too.
Per-repo rules: copy `config/ocr-rule.json.example` to `<repo>/.opencodereview/rule.json`.
Upstream docs: `tools/open-code-review/README.md`, `tools/open-code-review/pages/src/content/docs/en/`.

## reviewdog

```bash
ruff check --output-format=concise . | ccra reviewdog -efm='%f:%l:%c: %m' -reporter=local -diff="git diff main"
cat report.sarif | ccra reviewdog -f=sarif -reporter=gitlab-mr-discussion -filter-mode=nofilter
ccra reviewdog -conf=config/reviewdog.yml -runners=ruff,shellcheck -reporter=github-pr-review
```
GitLab reporters need `REVIEWDOG_GITLAB_API_TOKEN` (set via `GITLAB_TOKEN`) and, outside GitLab CI,
`GITLAB_API` plus the `CI_PROJECT_*`/`CI_MERGE_REQUEST_IID`/`CI_COMMIT_SHA` variables reviewdog
reads to locate the MR. Upstream docs: `tools/reviewdog/README.md`.

## pr-agent

```bash
ccra pr-agent --pr_url https://gitlab.example.com/g/p/-/merge_requests/42 review
ccra pr-agent --pr_url <url> describe
ccra pr-agent --pr_url <url> improve --extended
ccra pr-agent --pr_url <url> ask "Is the retry logic safe under concurrency?"
CONFIG__GIT_PROVIDER=local ccra pr-agent --pr_url main review     # local branch pair -> review.md
ccra pr-agent doctor
ccra pr-agent --pr_url <url> review --pr_reviewer.extra_instructions="focus on auth"   # any config key
```
Settings precedence: CLI `--section.key=value` > env `SECTION__KEY` > `.pr_agent.toml` in the
reviewed repo > `tools/pr-agent/pr_agent/settings/configuration.toml`. Per-repo template:
`config/pr_agent.toml.example`. Upstream docs: `tools/pr-agent/docs/docs/`.

Webhook/server modes (GitLab webhook, GitHub app, polling) are in `tools/pr-agent/pr_agent/servers/`
and run with the same venv: `PYTHONPATH=tools/pr-agent .ccra/venv/bin/python -m pr_agent.servers.gitlab_webhook`.

## ponytail

```bash
ccra agents claude            # register tools/ponytail and tools/open-code-review as local plugin marketplaces
ccra agents codex             # prints the codex commands with local paths
ccra agents cursor            # installs ponytail hooks + ocr plugin for Cursor
ccra agents opencode          # prints the opencode.json snippet
ccra agents skills ~/.claude/skills      # plain SKILL.md copies for any agent that reads them
ccra agents agents-md /path/to/project   # drop ponytail's AGENTS.md into a project
```
Inside the agent: `/ponytail` (`lite|full|ultra|off`), `/ponytail-review`, `/ponytail-audit`,
`/ponytail-debt`, `/ponytail-gain`, `/ponytail-help`. Default level: `PONYTAIL_DEFAULT_MODE`.
Upstream docs: `tools/ponytail/README.md`, `tools/ponytail/INSTALL.md`.

## CI

- GitLab: `ci/gitlab-ci.example.yml` (this repo's own `.gitlab-ci.yml` is a self-test).
- GitHub Actions: `ci/github-workflow.example.yml`.

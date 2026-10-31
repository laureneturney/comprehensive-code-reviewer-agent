# comprehensive-code-reviewer-agent

Four open-source code-review tools, vendored verbatim and packaged so they install and run
on a machine with **no access to GitHub, npm, PyPI or Docker Hub**:

| Tool | Version | Role | License |
|------|---------|------|---------|
| [open-code-review](tools/open-code-review) (`ocr`) by Alibaba | v1.13.3 | AI review of git diffs with deterministic file selection; SARIF/JSON output; delegate mode for coding agents | Apache-2.0 |
| [pr-agent](tools/pr-agent) | v0.49.0 | AI `/review`, `/describe`, `/improve`, `/ask` on GitLab MRs, GitHub PRs or local branches; any model via LiteLLM | MIT |
| [reviewdog](tools/reviewdog) | v0.21.2 | Posts linter and SARIF findings as inline MR/PR discussions, filtered to the diff | MIT |
| [ponytail](tools/ponytail) | v5.3.3 | "Lazy senior dev" rules and `/ponytail-review`, `/ponytail-audit` skills for Claude Code, Codex, Cursor, OpenCode and others | MIT |

`bin/ccra` is a thin front door that installs everything from the bundled assets and chains
the tools into one pipeline: **ocr → SARIF → reviewdog → your MR/PR**, with pr-agent's
summary alongside and ponytail shaping the coding agent itself. Each tool stays fully usable on
its own. Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Quick start (offline machine)

```bash
git clone <your-gitlab-mirror>/comprehensive-code-reviewer-agent.git
cd comprehensive-code-reviewer-agent
scripts/install.sh --prefix ~/.local/bin      # unpack binaries, build the pr-agent venv; no network
ccra doctor
```

Then, in a repository you want reviewed:

```bash
ccra ocr config provider && ccra ocr config model      # one-time LLM setup for ocr (or `ocr config set ...`)
ccra review --from main --to HEAD                       # AI review printed in the terminal
ccra review --reporter gitlab-mr-discussion --pr-url https://gitlab.example.com/g/p/-/merge_requests/42
ccra lint -reporter=local -diff="git diff main"         # ruff/eslint/golangci/shellcheck via reviewdog
ccra agents claude                                      # ponytail + ocr skills inside Claude Code
```

Tokens and model settings live in `.ccra/env` (template: [config/ccra.env.example](config/ccra.env.example)).
One `GITLAB_URL` + `GITLAB_TOKEN` (or `GITHUB_TOKEN`) feeds both reviewdog and pr-agent.

## What is in the box

```
bin/ccra                  front-door CLI (install, doctor, review, lint, ocr, reviewdog, pr-agent, agents)
scripts/install.sh        offline installer           scripts/verify-assets.sh   checksum check
scripts/fetch-offline-assets.sh / sync-upstream.sh    online-side refresh scripts
config/                   env template, reviewdog runners, per-repo samples for pr-agent and ocr
ci/                       GitLab CI and GitHub Actions examples;  .gitlab-ci.yml is this repo's self-test
docker/Dockerfile         all-in-one image built only from vendored assets
docs/                     ARCHITECTURE, OFFLINE_INSTALL, USAGE, UPSTREAM
tools/                    verbatim upstream sources (only .git removed)
vendor/binaries/          official ocr + reviewdog release binaries: linux amd64/arm64, macOS amd64/arm64
vendor/wheels/pr-agent/   pr-agent's locked dependencies as wheels: CPython 3.12, linux x86_64 + macOS arm64
vendor/MANIFEST.json      exact upstream commits/tags and what was vendored
```

## Requirements on the target machine

git >= 2.41, bash, tar/gzip, and for pr-agent a Python >= 3.12 with `venv`. Linux x86_64/arm64
or macOS. Node is optional (ponytail hooks). Other Python versions or platforms need a one-off
wheel refresh on a connected machine; see [docs/OFFLINE_INSTALL.md](docs/OFFLINE_INSTALL.md).

## Documentation

- [docs/OFFLINE_INSTALL.md](docs/OFFLINE_INSTALL.md): transferring the repo, requirements, install, configure, other platforms
- [docs/USAGE.md](docs/USAGE.md): every command, per tool and combined
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): how the pieces fit, where state lives, why it works offline
- [docs/UPSTREAM.md](docs/UPSTREAM.md): how to pull newer upstream versions
- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md): licenses and provenance

Upstream projects: [alibaba/open-code-review](https://github.com/alibaba/open-code-review),
[The-PR-Agent/pr-agent](https://github.com/The-PR-Agent/pr-agent),
[reviewdog/reviewdog](https://github.com/reviewdog/reviewdog),
[dietrichgebert/ponytail](https://github.com/dietrichgebert/ponytail).
The integration layer is MIT ([LICENSE](LICENSE)); each vendored tool keeps its own license.

# Offline installation

This repository is self-contained: source code of all four tools, prebuilt binaries for the
two Go tools, and a Python wheelhouse for pr-agent. The target machine never needs GitHub,
npm, PyPI or Docker Hub.

## 1. Get the repository onto the machine

Pick whichever route exists in your environment:

- **Internal GitLab mirror** (recommended): push this repo to your GitLab, then on the target: `git clone <internal-gitlab-url>`.
- **Git bundle on removable media** (keeps history): on a connected machine `git bundle create ccra.bundle --all`; on the target `git clone ccra.bundle comprehensive-code-reviewer-agent`.
- **Plain archive**: `git archive --format=tar.gz -o ccra.tar.gz HEAD` and extract on the target.

## 2. Target machine requirements

| Requirement | Needed by | Notes |
|-------------|-----------|-------|
| Linux x86_64 / arm64, or macOS arm64 / x86_64 | ocr, reviewdog | Binaries for these four platforms are vendored. Windows is not. |
| `git` >= 2.41 | everything | ocr refuses older git. |
| `bash`, `tar`, `gzip`, `sha256sum` or `shasum` | installer | Standard on Linux/macOS. |
| Python >= 3.12 with `venv` | pr-agent only | Wheels are vendored for **CPython 3.12 on Linux x86_64 and macOS arm64**. Other combinations: see §5. Debian/Ubuntu need `python3-venv`. |
| `node` >= 14 | optional | ponytail's lifecycle hooks and ocr's npm launcher. Skills work without it. |
| A coding agent (Claude Code, Codex, Cursor, OpenCode, ...) | optional | For ponytail and ocr delegate mode. |

## 3. Install

```bash
cd comprehensive-code-reviewer-agent
scripts/verify-assets.sh          # checksums of everything under vendor/
scripts/install.sh                # or: scripts/install.sh --prefix ~/.local/bin
bin/ccra doctor
```

`install.sh` unpacks `ocr` and `reviewdog` into `.ccra/bin/`, verifies them against the
upstream checksum files, creates `.ccra/venv` from the wheelhouse and writes `.ccra/env`
from `config/ccra.env.example`.

## 4. Configure

1. Edit `.ccra/env`: tokens for GitLab/GitHub and the LLM settings for pr-agent.
2. Configure ocr's LLM. Either three env vars in `.ccra/env`:
   ```bash
   OCR_LLM_URL=https://llm-gateway.internal/v1
   OCR_LLM_TOKEN=...
   OCR_LLM_MODEL=my-model
   OCR_LLM_PROTOCOL=openai        # or anthropic
   ```
   or a persistent config in `~/.opencodereview/config.json`:
   ```bash
   ccra ocr config set provider my-gateway
   ccra ocr config set custom_providers.my-gateway.url https://llm-gateway.internal/v1
   ccra ocr config set custom_providers.my-gateway.protocol openai      # or anthropic
   ccra ocr config set custom_providers.my-gateway.api_key "$LLM_KEY"
   ccra ocr config set model my-model
   ccra ocr llm test
   ```
   No LLM endpoint at all? Use delegate mode inside a coding agent (`ccra agents claude`).
3. `ccra pr-agent doctor` pings the pr-agent model and checks the configured sinks.

## 5. Other Python versions or platforms

The wheelhouse was built for CPython 3.12 on `manylinux x86_64` and `macosx arm64`. If the
target differs (for example Python 3.11, which pr-agent does not support, or Linux arm64),
run on a connected machine:

```bash
scripts/fetch-offline-assets.sh --wheels-only --python-version 3.13 --platform linux-arm64
git add vendor/wheels && git commit -m "wheels: cp313 linux-arm64" && git push
```

Then pull on the target and re-run `scripts/install.sh --force`.

## 6. Building the Go tools from source (optional)

`tools/open-code-review` and `tools/reviewdog` are complete sources, but `go build` needs
their module dependencies, which are not vendored (that needs Go and a module proxy on the
online side: `cd tools/<tool> && go mod vendor`). The prebuilt binaries are the supported path.

## 7. Docker (optional)

`docker/Dockerfile` builds an image from the vendored assets alone. The base image
(`python:3.12`, which includes git) must already be present on the daemon.

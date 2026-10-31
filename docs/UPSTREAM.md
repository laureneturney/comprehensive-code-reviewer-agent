# Upstream tracking

`vendor/MANIFEST.json` records, for each tool, the upstream URL, tag, commit and date that
`tools/<name>` was copied from, and which binaries/wheels were vendored. The copies are
verbatim (only `.git` removed); do not edit files under `tools/`, put integration code in
`bin/`, `scripts/`, `config/` instead so upstream syncs stay a plain overwrite.

## Updating (needs a machine with internet)

```bash
scripts/sync-upstream.sh --latest                 # or --only pr-agent --ref pr-agent=v0.50.0
scripts/fetch-offline-assets.sh --ocr-version v1.14.0 --reviewdog-version v0.22.0 --relock
# edit vendor/MANIFEST.json and THIRD_PARTY_NOTICES.md with the printed commits/tags
scripts/verify-assets.sh --deep
scripts/install.sh --force && bin/ccra doctor
git add -A && git commit -m "sync upstream: ..." && git push
```

Things to re-check after a sync:

- open-code-review: `bin/ocr.js` still falls back to `bin/opencodereview` (we bypass npm entirely, so only the Go binary matters); release asset names unchanged.
- reviewdog: release archive naming `reviewdog_<ver>_<OS>_<ARCH>.tar.gz`.
- pr-agent: `requires-python` in `pyproject.toml`; the `uv` version its lockfile demands; the `LITELLM_LOCAL_MODEL_COST_MAP` env var and the tiktoken bundling in `pr_agent/algo/token_handler.py`.
- ponytail: `.claude-plugin/marketplace.json` still points at `./`; hook file names in `hooks/`.

## Initial import

Imported 2026-10-31 on macOS arm64 from the commits listed in `vendor/MANIFEST.json`.
Binaries were downloaded from the official GitHub releases and verified against the upstream
checksum files; the wheelhouse was produced with `pip download` from PyPI against the
`uv export` of pr-agent's lockfile (uv 0.13.5).

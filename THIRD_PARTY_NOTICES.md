# Third-party notices

This repository bundles four open-source projects as **verbatim copies** of
their upstream sources (only the `.git` history was removed) so they can be
installed on a machine with no access to GitHub, npm, PyPI or Docker Hub.
Each copy keeps its original `LICENSE` file in place. Nothing in `tools/` was
modified; all integration code lives outside `tools/`.

| Tool | Path | Upstream | Version | Commit | License |
|------|------|----------|---------|--------|---------|
| Open Code Review (`ocr`) | `tools/open-code-review` | https://github.com/alibaba/open-code-review | v1.13.3 | `216dcf513593055a70165f793e96b52589d71b1b` | Apache-2.0 (`tools/open-code-review/LICENSE`) |
| Ponytail | `tools/ponytail` | https://github.com/dietrichgebert/ponytail | v5.3.3 | `96608e078b2d5ea607c5c3b8b5a54d1c1fba6846` | MIT (`tools/ponytail/LICENSE`) |
| PR-Agent | `tools/pr-agent` | https://github.com/The-PR-Agent/pr-agent | v0.49.0 | `7bb7a68b451097d79dbc1c470e849b78dcf07eed` | MIT (`tools/pr-agent/LICENSE`) |
| reviewdog | `tools/reviewdog` | https://github.com/reviewdog/reviewdog | v0.21.2 | `7334fb196a20ce543a1d4142ce06d591d0e846b8` | MIT (`tools/reviewdog/LICENSE`) |

## Prebuilt assets under `vendor/`

| Asset | Source | Notes |
|-------|--------|-------|
| `vendor/binaries/open-code-review/opencodereview-*.gz` | GitHub release `alibaba/open-code-review` v1.13.3 | Official release binaries, gzip-compressed here. `sha256sum.txt` is the upstream checksum file for the uncompressed binaries. Apache-2.0. |
| `vendor/binaries/reviewdog/reviewdog_0.21.2_*.tar.gz` | GitHub release `reviewdog/reviewdog` v0.21.2 | Official release archives, unmodified. `checksums.txt` is the upstream checksum file. MIT. |
| `vendor/wheels/pr-agent/*.whl` | PyPI | The exact dependency set resolved by PR-Agent's `uv.lock` (base + `github` + `gitlab` extras) plus `pip`, `setuptools`, `wheel`. Each wheel carries its own license; see the package metadata inside each `.whl`. |

## Apache-2.0 notice (Open Code Review)

Open Code Review is licensed under the Apache License, Version 2.0. A copy of
the license is at `tools/open-code-review/LICENSE`. The source files carry
`SPDX-License-Identifier: Apache-2.0` headers and the copyright line
"Copyright 2026 alibaba/open-code-review Contributors". No upstream NOTICE
file exists at the vendored commit. The copy in this repository is unmodified.

## MIT notices

Ponytail: Copyright (c) 2026 DietrichGebert.
PR-Agent: Copyright (c) 2026 The PR Agent (originally Codium/Qodo).
reviewdog: Copyright (c) 2016 haya14busa.

Full license texts are in each tool's `LICENSE` file.

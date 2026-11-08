#!/usr/bin/env bash
# ONLINE-SIDE script: (re)download the prebuilt assets that make this repository installable offline.
# Run on a machine with internet, then commit vendor/ and push to the mirror the offline machine can reach.
#
#   scripts/fetch-offline-assets.sh [options]
#     --ocr-version vX.Y.Z          default: tag in vendor/MANIFEST.json
#     --reviewdog-version vX.Y.Z    default: tag in vendor/MANIFEST.json
#     --platform TAG                binary/wheel platform; repeatable. Default: linux-amd64 linux-arm64 darwin-amd64 darwin-arm64
#                                   wheel TAGs: linux-amd64 -> manylinux x86_64, linux-arm64 -> manylinux aarch64,
#                                   darwin-arm64 -> macosx arm64, darwin-amd64 -> macosx x86_64
#     --python-version X.Y          CPython version for the wheelhouse (default 3.12); repeatable
#     --binaries-only | --wheels-only
#     --relock                      regenerate requirements.lock.txt from tools/pr-agent/uv.lock (needs uv >= 0.13.5)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/vendor/MANIFEST.json"
tag_of() { awk -v n="$1" '$0 ~ "\"name\": \""n"\"" {f=1} f && /"tag":/ {gsub(/[",]/,"",$2); print $2; exit}' "$MANIFEST"; }
OCR_VER="$(tag_of open-code-review)"; RD_VER="$(tag_of reviewdog)"
PLATFORMS=(); PYVERS=(); DO_BIN=1; DO_WHL=1; RELOCK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ocr-version) OCR_VER="$2"; shift 2 ;;
    --reviewdog-version) RD_VER="$2"; shift 2 ;;
    --platform) PLATFORMS+=("$2"); shift 2 ;;
    --python-version) PYVERS+=("$2"); shift 2 ;;
    --binaries-only) DO_WHL=0; shift ;;
    --wheels-only) DO_BIN=0; shift ;;
    --relock) RELOCK=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
[ ${#PLATFORMS[@]} -gt 0 ] || PLATFORMS=(linux-amd64 linux-arm64 darwin-amd64 darwin-arm64)
[ ${#PYVERS[@]} -gt 0 ] || PYVERS=(3.12)
fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }

if [ $DO_BIN -eq 1 ]; then
  d="$ROOT/vendor/binaries/open-code-review"; mkdir -p "$d"; tmp="$(mktemp -d)"
  base="https://github.com/alibaba/open-code-review/releases/download/$OCR_VER"
  echo "==> open-code-review $OCR_VER"
  fetch "$base/sha256sum.txt" "$d/sha256sum.txt"
  for p in "${PLATFORMS[@]}"; do
    f="opencodereview-$p"; fetch "$base/$f" "$tmp/$f"
    ( cd "$tmp" && grep " $f\$" "$d/sha256sum.txt" | { sha256sum -c --quiet - 2>/dev/null || shasum -a 256 -c - >/dev/null; } ) || { echo "checksum failed: $f" >&2; exit 1; }
    gzip -9 -c "$tmp/$f" > "$d/$f.gz"; echo "   $f.gz"
  done
  ( cd "$d" && { sha256sum *.gz 2>/dev/null || shasum -a 256 *.gz; } > SHA256SUMS-gz.txt ); rm -rf "$tmp"

  d="$ROOT/vendor/binaries/reviewdog"; mkdir -p "$d"
  base="https://github.com/reviewdog/reviewdog/releases/download/$RD_VER"; v="${RD_VER#v}"
  echo "==> reviewdog $RD_VER"
  fetch "$base/checksums.txt" "$d/checksums.txt"
  for p in "${PLATFORMS[@]}"; do
    case "$p" in linux-amd64) a=Linux_x86_64;; linux-arm64) a=Linux_arm64;; darwin-amd64) a=Darwin_x86_64;; darwin-arm64) a=Darwin_arm64;; *) echo "skip $p" >&2; continue;; esac
    f="reviewdog_${v}_${a}.tar.gz"; fetch "$base/$f" "$d/$f"; echo "   $f"
  done
  ( cd "$d" && { sha256sum -c --ignore-missing --quiet checksums.txt 2>/dev/null || shasum -a 256 -c --ignore-missing checksums.txt >/dev/null; } && { sha256sum *.tar.gz 2>/dev/null || shasum -a 256 *.tar.gz; } > SHA256SUMS.txt )
fi

if [ $DO_WHL -eq 1 ]; then
  W="$ROOT/vendor/wheels/pr-agent"; T="$ROOT/vendor/wheels/tools"; mkdir -p "$W" "$T"
  if [ $RELOCK -eq 1 ] || [ ! -f "$W/requirements.lock.txt" ]; then
    command -v uv >/dev/null 2>&1 || { echo "uv >= 0.13.5 is required for --relock" >&2; exit 1; }
    ( cd "$ROOT/tools/pr-agent" && uv export --frozen --no-dev --no-hashes --no-emit-project --extra github --extra gitlab --format requirements-txt -o "$W/requirements.lock.txt" )
  fi
  PIP="${PIP:-python3 -m pip}"
  for pv in "${PYVERS[@]}"; do
    abi="cp${pv/./}"
    for p in "${PLATFORMS[@]}"; do
      case "$p" in
        linux-amd64)  tags=(manylinux2014_x86_64 manylinux_2_17_x86_64 manylinux_2_28_x86_64 manylinux_2_34_x86_64 linux_x86_64) ;;
        linux-arm64)  tags=(manylinux2014_aarch64 manylinux_2_17_aarch64 manylinux_2_28_aarch64 manylinux_2_34_aarch64 linux_aarch64) ;;
        darwin-arm64) tags=(macosx_11_0_arm64 macosx_12_0_arm64 macosx_13_0_arm64 macosx_14_0_arm64 macosx_15_0_arm64) ;;
        darwin-amd64) tags=(macosx_10_13_x86_64 macosx_11_0_x86_64 macosx_12_0_x86_64 macosx_13_0_x86_64 macosx_14_0_x86_64) ;;
        *) echo "skip $p" >&2; continue ;;
      esac
      echo "==> wheels for cp$pv $p"
      args=(); for t in "${tags[@]}"; do args+=(--platform "$t"); done
      $PIP download -r "$W/requirements.lock.txt" -d "$W" --only-binary=:all: "${args[@]}" --python-version "$pv" --implementation cp --abi "$abi" --abi abi3 --abi none -q
      $PIP download pip setuptools wheel -d "$W" --only-binary=:all: --python-version "$pv" -q
      $PIP download ruff -d "$T" --only-binary=:all: "${args[@]}" --python-version "$pv" --implementation cp --abi "$abi" --abi abi3 --abi none -q
    done
  done
  ( cd "$W" && { sha256sum *.whl 2>/dev/null || shasum -a 256 *.whl; } > SHA256SUMS.txt )
  ( cd "$T" && { sha256sum *.whl 2>/dev/null || shasum -a 256 *.whl; } > SHA256SUMS.txt )
  echo "wheelhouse: $(ls "$W"/*.whl | wc -l | tr -d ' ') wheels, $(du -sh "$W" | cut -f1)"
fi
echo "done. Review 'git status', then commit vendor/ and update vendor/MANIFEST.json if versions changed."

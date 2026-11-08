#!/usr/bin/env bash
# Offline installer for comprehensive-code-reviewer-agent.
# Unpacks the vendored ocr and reviewdog binaries and builds the pr-agent venv from the
# vendored wheelhouse. Makes NO network requests.
#
#   scripts/install.sh [--prefix DIR] [--python BIN] [--skip-python] [--force] [--allow-network [--index-url URL]]
#     --prefix DIR      also symlink ccra, ocr, reviewdog, pr-agent into DIR (e.g. ~/.local/bin, /usr/local/bin)
#     --python BIN      python >= 3.12 to build the venv with (default: first of python3.12 python3.13 python3.14 python3)
#     --skip-python     install only the Go binaries (ocr, reviewdog)
#     --force           rebuild even if already installed
#     --allow-network   if the vendored wheelhouse lacks wheels for this Python/platform, fall back to pip's
#                       package index (PyPI, or --index-url for an internal mirror). Default: never touch the network.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CCRA_HOME="${CCRA_HOME:-$ROOT/.ccra}"
PREFIX="" PYTHON="" SKIP_PYTHON=0 FORCE=0 ALLOW_NETWORK=0 INDEX_URL=""

die()  { echo "install: $*" >&2; exit 1; }
note() { echo "==> $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --python) PYTHON="$2"; shift 2 ;;
    --skip-python) SKIP_PYTHON=1; shift ;;
    --force) FORCE=1; shift ;;
    --allow-network) ALLOW_NETWORK=1; shift ;;
    --index-url) INDEX_URL="$2"; shift 2 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) die "unknown option $1" ;;
  esac
done

sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
expected_sum() { awk -v f="$1" '$2==f || $2=="*"f {print $1}' "$2" | head -1; }

OS="$(uname -s)"; ARCH="$(uname -m)"
case "$OS" in
  Linux)  ocr_os=linux;  rd_os=Linux ;;
  Darwin) ocr_os=darwin; rd_os=Darwin ;;
  *) die "unsupported OS: $OS (vendored binaries cover Linux and macOS)" ;;
esac
case "$ARCH" in
  x86_64|amd64)  ocr_arch=amd64; rd_arch=x86_64 ;;
  aarch64|arm64) ocr_arch=arm64; rd_arch=arm64 ;;
  *) die "unsupported architecture: $ARCH" ;;
esac
note "platform: $OS/$ARCH  ->  ocr $ocr_os-$ocr_arch, reviewdog ${rd_os}_${rd_arch}"

mkdir -p "$CCRA_HOME/bin"
BIN="$CCRA_HOME/bin"

# ---- open-code-review -------------------------------------------------------
OCR_DIR="$ROOT/vendor/binaries/open-code-review"
OCR_GZ="$OCR_DIR/opencodereview-$ocr_os-$ocr_arch.gz"
if [ -x "$BIN/ocr" ] && [ $FORCE -eq 0 ]; then
  note "ocr already installed ($("$BIN/ocr" --version 2>/dev/null | head -1)); use --force to reinstall"
else
  [ -f "$OCR_GZ" ] || die "no vendored ocr binary for $ocr_os/$ocr_arch. Fetch one online with scripts/fetch-offline-assets.sh --binaries-only"
  note "installing ocr from $(basename "$OCR_GZ")"
  gunzip -c "$OCR_GZ" > "$BIN/ocr.tmp"
  want="$(expected_sum "opencodereview-$ocr_os-$ocr_arch" "$OCR_DIR/sha256sum.txt")"
  got="$(sha256 "$BIN/ocr.tmp")"
  [ -n "$want" ] && [ "$want" = "$got" ] || { rm -f "$BIN/ocr.tmp"; die "sha256 mismatch for ocr (want ${want:-?}, got $got)"; }
  mv "$BIN/ocr.tmp" "$BIN/ocr" && chmod +x "$BIN/ocr"
fi

# ---- reviewdog --------------------------------------------------------------
RD_DIR="$ROOT/vendor/binaries/reviewdog"
RD_TGZ="$(ls "$RD_DIR"/reviewdog_*_"${rd_os}"_"${rd_arch}".tar.gz 2>/dev/null | head -1 || true)"
if [ -x "$BIN/reviewdog" ] && [ $FORCE -eq 0 ]; then
  note "reviewdog already installed ($("$BIN/reviewdog" -version 2>/dev/null)); use --force to reinstall"
else
  [ -n "$RD_TGZ" ] || die "no vendored reviewdog archive for ${rd_os}_${rd_arch}. Fetch one online with scripts/fetch-offline-assets.sh --binaries-only"
  note "installing reviewdog from $(basename "$RD_TGZ")"
  want="$(expected_sum "$(basename "$RD_TGZ")" "$RD_DIR/checksums.txt")"
  got="$(sha256 "$RD_TGZ")"
  [ -n "$want" ] && [ "$want" = "$got" ] || die "sha256 mismatch for $(basename "$RD_TGZ")"
  tmp="$(mktemp -d)"; tar -xzf "$RD_TGZ" -C "$tmp" reviewdog
  mv "$tmp/reviewdog" "$BIN/reviewdog" && chmod +x "$BIN/reviewdog"; rm -rf "$tmp"
fi

# macOS: clear the quarantine bit so the binaries run without a Gatekeeper prompt
if [ "$OS" = Darwin ] && command -v xattr >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$BIN/ocr" "$BIN/reviewdog" 2>/dev/null || true
fi

# ---- pr-agent (python venv from the wheelhouse) ------------------------------
WHEELS="$ROOT/vendor/wheels/pr-agent"
if [ $SKIP_PYTHON -eq 1 ]; then
  note "skipping pr-agent (--skip-python)"
else
  find_python() {
    local c
    for c in ${PYTHON:+"$PYTHON"} python3.12 python3.13 python3.14 python3; do
      if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' 2>/dev/null; then
        command -v "$c"; return 0
      fi
    done
    return 1
  }
  if PY="$(find_python)"; then
    if [ -x "$CCRA_HOME/venv/bin/python" ] && [ $FORCE -eq 0 ]; then
      note "pr-agent venv already present; use --force to rebuild"
    else
      note "building pr-agent venv with $PY ($("$PY" --version 2>&1))"
      rm -rf "$CCRA_HOME/venv"
      "$PY" -m venv "$CCRA_HOME/venv" || die "python -m venv failed (on Debian/Ubuntu install the python3-venv package)"
      VPY="$CCRA_HOME/venv/bin/python"
      "$VPY" -m pip install --no-index --find-links "$WHEELS" --upgrade pip setuptools wheel -q 2>/dev/null || true
      if ! "$VPY" -m pip install --no-index --find-links "$WHEELS" -r "$WHEELS/requirements.lock.txt" -q 2>"$CCRA_HOME/pip-offline.log"; then
        pyver="$("$VPY" -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
        plat="$("$VPY" -c 'import sysconfig; print(sysconfig.get_platform())')"
        case "$plat" in
          *linux*x86_64*) tag=linux-amd64 ;; *linux*aarch64*|*linux*arm64*) tag=linux-arm64 ;;
          *macosx*arm64*) tag=darwin-arm64 ;; *macosx*x86_64*) tag=darwin-amd64 ;; *) tag="$plat" ;;
        esac
        if [ $ALLOW_NETWORK -eq 1 ]; then
          note "wheelhouse has no match for CPython $pyver on $plat; retrying with the package index ${INDEX_URL:-(default PyPI)}"
          "$VPY" -m pip install ${INDEX_URL:+--index-url "$INDEX_URL"} --find-links "$WHEELS" -r "$WHEELS/requirements.lock.txt" -q \
            || die "pip install from the package index failed (see output above)"
        else
          cat >&2 <<MSG
install: the vendored wheelhouse has no wheels for CPython $pyver on $plat
  (first missing package: $(grep -m1 -o 'for [a-zA-Z0-9_.-]*==[0-9a-z.]*' "$CCRA_HOME/pip-offline.log" | head -1)).
  Bundled Python versions and platforms are listed in vendor/MANIFEST.json under wheels.pr-agent.
  Options:
    a) this machine can reach PyPI or an internal mirror:
         scripts/install.sh --allow-network [--index-url https://mirror.example/simple]${PREFIX:+ --prefix $PREFIX}
    b) a connected machine refreshes the wheelhouse, then commit, push and pull here:
         scripts/fetch-offline-assets.sh --wheels-only --python-version $pyver --platform $tag
    c) use a bundled Python version instead: scripts/install.sh --python /path/to/python3.12${PREFIX:+ --prefix $PREFIX}
  ocr and reviewdog are installed; only pr-agent (and ruff) are missing.
MSG
          exit 1
        fi
      fi
      # Vendored ruff (vendor/wheels/tools) powers `ccra lint` and `ccra audit` offline.
      if ls "$ROOT/vendor/wheels/tools"/ruff-*.whl >/dev/null 2>&1; then
        if "$VPY" -m pip install --no-index --find-links "$ROOT/vendor/wheels/tools" ruff -q 2>/dev/null \
           || { [ $ALLOW_NETWORK -eq 1 ] && "$VPY" -m pip install ${INDEX_URL:+--index-url "$INDEX_URL"} ruff -q; }; then
          note "ruff $("$CCRA_HOME/venv/bin/ruff" --version 2>/dev/null | awk '{print $2}') installed into the venv (ccra lint / ccra audit)"
        else
          note "no ruff wheel for this platform; ccra lint/audit will use ruff from PATH or uvx"
        fi
      fi
      # Editable install (no deps, no build isolation) so `pr-agent --version` and package
      # metadata resolve from any directory. Falls back to plain PYTHONPATH if it fails.
      if ! "$VPY" -m pip install --no-index --no-deps --no-build-isolation -e "$ROOT/tools/pr-agent" -q 2>/dev/null; then
        note "editable install of pr-agent skipped (setuptools missing?); ccra uses PYTHONPATH instead"
      fi
    fi
    cat > "$BIN/pr-agent" <<SHIM
#!/usr/bin/env bash
exec "$ROOT/bin/ccra" pr-agent "\$@"
SHIM
    chmod +x "$BIN/pr-agent"
  else
    echo "install: no python >= 3.12 found; ocr and reviewdog are installed, pr-agent is not. Re-run with --python /path/to/python3.12" >&2
  fi
fi

# ---- env file + prefix symlinks ----------------------------------------------
[ -f "$CCRA_HOME/env" ] || { cp "$ROOT/config/ccra.env.example" "$CCRA_HOME/env"; note "created $CCRA_HOME/env (edit it to add tokens / LLM settings)"; }
if [ -n "$PREFIX" ]; then
  mkdir -p "$PREFIX"
  ln -sf "$ROOT/bin/ccra" "$PREFIX/ccra"
  ln -sf "$BIN/ocr" "$PREFIX/ocr"
  ln -sf "$BIN/reviewdog" "$PREFIX/reviewdog"
  [ -x "$BIN/pr-agent" ] && ln -sf "$BIN/pr-agent" "$PREFIX/pr-agent"
  note "symlinked ccra, ocr, reviewdog$([ -x "$BIN/pr-agent" ] && echo ', pr-agent') into $PREFIX"
fi

echo
note "installed into $CCRA_HOME"
echo "  ocr:        $("$BIN/ocr" --version 2>/dev/null | head -1)"
echo "  reviewdog:  $("$BIN/reviewdog" -version 2>/dev/null)"
[ -x "$CCRA_HOME/venv/bin/python" ] && echo "  pr-agent:   $(cd "$ROOT/tools/pr-agent" && PYTHONPATH="$ROOT/tools/pr-agent" LITELLM_LOCAL_MODEL_COST_MAP=True "$CCRA_HOME/venv/bin/python" -m pr_agent.cli --version 2>/dev/null | tail -1)"
echo "  ponytail:   tools/ponytail (install into an agent with: ccra agents claude|codex|cursor|opencode)"
echo
echo "Next: edit $CCRA_HOME/env, then \`$ROOT/bin/ccra doctor\`."
[ -z "$PREFIX" ] && echo "Tip: add $ROOT/bin to PATH, or re-run with --prefix ~/.local/bin"
exit 0

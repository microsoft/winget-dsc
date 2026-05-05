#!/usr/bin/env bash
# =============================================================================
#  Python install script for Debian/Ubuntu (incl. WSL).
#
#  Mirrors the Windows Python flow: this is the "install" half — CI then drives
#  tests/_harness via manifest.yml to prove the install actually works.
#
#  Responsibilities:
#    * Install CPython 3 + pip + the `python-is-python3` alias via apt
#      (idempotent — apt no-ops when packages are already present). The alias
#      is what lets the manifest's `python tests/python/hello.py` run command
#      be identical across Windows and Linux.
#    * Install uv (Astral's Python package/project manager) via the official
#      standalone installer — uv is not packaged in Debian/Ubuntu apt repos
#      yet, and `astral.sh/uv/install.sh` is the Astral-documented method.
#    * Retry network operations on transient failure (hosted runners are flaky).
#    * Ensure $HOME/.local/bin (uv's install dir) is on PATH for subsequent
#      CI steps via $GITHUB_PATH.
#    * Verify `python`, `pip3`, and `uv` resolve on PATH.
#    * Emit `INSTALL_OK: python` as the final line, which CI asserts on.
# =============================================================================

set -euo pipefail

ID="python"

log() { printf '[%s] %s\n' "$ID" "$*"; }

# ---- retry helper -----------------------------------------------------------
# Exponential backoff (5s, 10s, 20s, 40s) — same spirit as _common/invoke-retry.ps1.
retry() {
    local -i n=0 max=5 delay=5
    while true; do
        if "$@"; then
            return 0
        fi
        n=$((n + 1))
        if (( n >= max )); then
            log "command failed after ${n} attempts: $*"
            return 1
        fi
        log "attempt ${n} failed; retrying in ${delay}s: $*"
        sleep "${delay}"
        delay=$((delay * 2))
    done
}

# ---- sudo selection ---------------------------------------------------------
# Works whether we're invoked as root (container) or a sudoer (CI / WSL default).
SUDO=()
if [[ "$(id -u)" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO=(sudo -E)
    else
        log "ERROR: not running as root and 'sudo' is not available"
        exit 1
    fi
fi

# ---- sanity: this script targets Debian/Ubuntu ------------------------------
if ! command -v apt-get >/dev/null 2>&1; then
    log "ERROR: apt-get not found; this flow currently supports Debian/Ubuntu (incl. WSL)."
    exit 1
fi

# ---- install python + pip + python-is-python3 alias -------------------------
export DEBIAN_FRONTEND=noninteractive

log "apt-get update"
retry "${SUDO[@]}" apt-get update -y

log "apt-get install python3 python3-pip python-is-python3"
retry "${SUDO[@]}" apt-get install -y --no-install-recommends \
    python3 python3-pip python-is-python3

# ---- install uv -------------------------------------------------------------
# Installer default target is $HOME/.local/bin/uv. Setting UV_INSTALL_DIR
# explicitly documents intent and makes the PATH addition below unambiguous.
UV_INSTALL_DIR="${UV_INSTALL_DIR:-$HOME/.local/bin}"
export UV_INSTALL_DIR

if command -v uv >/dev/null 2>&1; then
    log "uv already installed: $(uv --version)"
else
    log "installing uv via astral.sh/uv/install.sh into ${UV_INSTALL_DIR}"
    retry bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
fi

# Make uv visible in THIS process for the verification step below.
export PATH="${UV_INSTALL_DIR}:${PATH}"

# Propagate to subsequent GitHub Actions steps, if running in CI.
if [[ -n "${GITHUB_PATH:-}" ]]; then
    echo "${UV_INSTALL_DIR}" >> "${GITHUB_PATH}"
fi

# ---- verify ----------------------------------------------------------------
for cmd in python pip3 uv; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "ERROR: $cmd not found on PATH after install"
        exit 1
    fi
done

log "$(python --version 2>&1 | head -n1)"
log "$(pip3 --version | head -n1)"
log "$(uv --version)"
echo "INSTALL_OK: ${ID}"

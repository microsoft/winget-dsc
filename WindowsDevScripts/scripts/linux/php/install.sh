#!/usr/bin/env bash
# =============================================================================
#  PHP install script for Debian/Ubuntu (incl. WSL).
#
#  Mirrors the Windows PHP flow: this is the "install" half — CI then drives
#  tests/_harness via manifest.yml to prove the install actually works.
#
#  Responsibilities:
#    * Install the php CLI via apt (idempotent — no-op if already present).
#    * Retry apt-get on transient network failures (hosted runners are flaky).
#    * Verify `php` resolves on PATH.
#    * Emit `INSTALL_OK: php` as the final line, which CI asserts on.
# =============================================================================

set -euo pipefail

ID="php"

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

# ---- fast path: already installed ------------------------------------------
if command -v php >/dev/null 2>&1; then
    log "php already installed: $(php --version | head -n1)"
    echo "INSTALL_OK: ${ID}"
    exit 0
fi

# ---- install ---------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive

log "apt-get update"
retry "${SUDO[@]}" apt-get update -y

log "apt-get install php-cli"
retry "${SUDO[@]}" apt-get install -y --no-install-recommends php-cli

# ---- verify ----------------------------------------------------------------
if ! command -v php >/dev/null 2>&1; then
    log "ERROR: php not found on PATH after install"
    exit 1
fi

log "$(php --version | head -n1)"
echo "INSTALL_OK: ${ID}"

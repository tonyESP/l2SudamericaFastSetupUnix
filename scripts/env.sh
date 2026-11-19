#!/usr/bin/env bash
# Environment and common variables for Lineage 2 Linux project

set -euo pipefail

export L2_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export L2_CLIENTS_DIR="${L2_PROJECT_ROOT}/clients"
export L2_PREFIXES_DIR="${L2_PROJECT_ROOT}/prefixes"
export L2_TOOLS_DIR="${L2_PROJECT_ROOT}/tools"
export L2_RUNNERS_DIR="${L2_TOOLS_DIR}/runners"
export L2_DOWNLOADS_DIR="${L2_PROJECT_ROOT}/downloads"
export L2_CONFIG_DIR="${L2_PROJECT_ROOT}/config"

# Load local non-committed credentials if present
if [[ -f "${L2_PROJECT_ROOT}/.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${L2_PROJECT_ROOT}/.env"
    set +a
fi

# Display settings for X11 / Wayland
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-${HOME:-/tmp}/.Xauthority}"

# NVIDIA Prime Render Offload for Hybrid Intel/NVIDIA laptop setup
export __NV_PRIME_RENDER_OFFLOAD=1
export __VK_LAYER_NV_optimus=NVIDIA_only

# Wine DLL overrides for custom server loaders (dsetup.dll)
export WINEDLLOVERRIDES="dsetup=n,b;${WINEDLLOVERRIDES:-}"

# DXVK optimizations
export DXVK_LOG_LEVEL=none
export DXVK_STATE_CACHE=1
export DXVK_STATE_CACHE_PATH="${L2_TOOLS_DIR}/dxvk_cache"
mkdir -p "${DXVK_STATE_CACHE_PATH}"

# WINE performance variables
export WINEESYNC=1
export WINEFSYNC=1

# Wine low-latency audio for snappy Soulshots and spell effects (PipeWire/PulseAudio)
export PULSE_LATENCY_MSEC=30

# Helper colors
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

log_info()    { echo -e "${C_CYAN}[INFO]${C_RESET} $*"; }
log_success() { echo -e "${C_GREEN}[SUCCESS]${C_RESET} $*"; }
log_warn()    { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
log_error()   { echo -e "${C_RED}[ERROR]${C_RESET} $*" >&2; }

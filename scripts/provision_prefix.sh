#!/usr/bin/env bash
# Unattended Wine prefix provisioning script for Lineage 2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

SERVER_ID="${1:-}"

if [[ -z "${SERVER_ID}" ]]; then
    log_error "Uso: $0 <server_id>"
    log_info "Ejemplo: $0 elmorelab-erica"
    exit 1
fi

PREFIX_PATH="${L2_PREFIXES_DIR}/${SERVER_ID}"

log_info "Aprovisionando prefijo Wine aislado para: ${SERVER_ID}"
log_info "Ruta de destino: ${PREFIX_PATH}"

# Ensure winetricks is available
WINETRICKS_BIN=""
if command -v winetricks >/dev/null 2>&1; then
    WINETRICKS_BIN=$(command -v winetricks)
else
    WINETRICKS_BIN="${L2_TOOLS_DIR}/winetricks"
    if [[ ! -f "${WINETRICKS_BIN}" ]]; then
        log_info "Descargando winetricks standalone..."
        curl -fSL "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" -o "${WINETRICKS_BIN}"
        chmod +x "${WINETRICKS_BIN}"
    fi
fi

# Locate Wine runner
RUNNER_BIN=""
if [[ -x "${L2_RUNNERS_DIR}/current/bin/wine" ]]; then
    RUNNER_BIN="${L2_RUNNERS_DIR}/current/bin/wine"
elif command -v wine >/dev/null 2>&1; then
    RUNNER_BIN=$(command -v wine)
else
    log_error "No se encontró Wine. Ejecuta primero: ${SCRIPT_DIR}/setup_runner.sh download"
    exit 1
fi

export WINE="${RUNNER_BIN}"
export WINEPREFIX="${PREFIX_PATH}"
export WINEARCH="win32"

log_info "Inicializando Wineprefix (32-bit arch)..."
"${WINE}" wineboot --init

log_info "Instalando dependencias esenciales desatendidas (corefonts, tahoma, d3dx9, vcrun2008, msxml4)..."
"${WINETRICKS_BIN}" -q corefonts tahoma d3dx9 vcrun2008 msxml4 || {
    log_warn "Algunas dependencias opcionales reportaron advertencias, continuando..."
}

# Copy DXVK config template if available
if [[ -f "${L2_CONFIG_DIR}/dxvk.conf.template" ]]; then
    mkdir -p "${PREFIX_PATH}/drive_c"
    cp "${L2_CONFIG_DIR}/dxvk.conf.template" "${PREFIX_PATH}/drive_c/dxvk.conf"
    log_info "dxvk.conf inyectado en el prefijo."
fi

log_success "Prefijo ${SERVER_ID} aprovisionado correctamente en ${PREFIX_PATH}"

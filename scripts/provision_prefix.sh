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
export WINESERVER="$(dirname "${RUNNER_BIN}")/wineserver"
export PATH="$(dirname "${RUNNER_BIN}"):${PATH}"
export WINEPREFIX="${PREFIX_PATH}"
export WINEARCH="win32"

log_info "Inicializando Wineprefix (32-bit arch)..."
"${WINE}" wineboot --init
"${WINESERVER}" -w

# Extract winetricks packages dynamically from config/servers.json (SOLID Open/Closed)
TRICKS_STR=$(python3 -c "
import json, sys
try:
    with open('${L2_CONFIG_DIR}/servers.json') as f:
        data = json.load(f)
    tricks = data.get('servers', {}).get('${SERVER_ID}', {}).get('winetricks', [])
    print(' '.join(tricks))
except Exception:
    sys.exit(0)
")

TRICKS=()
if [[ -n "${TRICKS_STR}" ]]; then
    read -r -a TRICKS <<< "${TRICKS_STR}"
fi

if [[ ${#TRICKS[@]} -eq 0 ]]; then
    TRICKS=(corefonts tahoma d3dx9 vcrun2008 msxml4)
fi

log_info "Instalando dependencias desatendidas: ${TRICKS[*]}..."
"${WINETRICKS_BIN}" -q "${TRICKS[@]}" || {
    log_warn "Algunas dependencias opcionales reportaron advertencias, continuando..."
}

"${WINESERVER}" -w

# Disable Wine mouse acceleration for linear 1:1 camera rotation
if [[ -f "${PREFIX_PATH}/user.reg" ]]; then
    sed -i -E 's/^"MouseSpeed"=.*/"MouseSpeed"="0"/; s/^"MouseThreshold1"=.*/"MouseThreshold1"="0"/; s/^"MouseThreshold2"=.*/"MouseThreshold2"="0"/' "${PREFIX_PATH}/user.reg"
    log_info "Aceleración de ratón desactivada en user.reg (giro 1:1)."

    if ! grep -q '\[Software\\\\Wine\\\\WineDbg\]' "${PREFIX_PATH}/user.reg"; then
        cat << 'EOF' >> "${PREFIX_PATH}/user.reg"

[Software\\Wine\\WineDbg]
"ShowCrashDialog"=dword:00000000
EOF
        log_info "Ventanas emergentes de crash desactivadas en WineDbg."
    fi

    if ! grep -q '\[Software\\\\Wine\\\\X11 Driver\]' "${PREFIX_PATH}/user.reg"; then
        cat << 'EOF' >> "${PREFIX_PATH}/user.reg"

[Software\\Wine\\X11 Driver]
"UseTakeFocus"="N"
EOF
        log_info "UseTakeFocus=N configurado en X11 Driver (evita bloqueos de foco con GNOME/Super)."
    fi
fi

# Copy DXVK config template if available
if [[ -f "${L2_CONFIG_DIR}/dxvk.conf.template" ]]; then
    mkdir -p "${PREFIX_PATH}/drive_c"
    cp "${L2_CONFIG_DIR}/dxvk.conf.template" "${PREFIX_PATH}/drive_c/dxvk.conf"
    log_info "dxvk.conf inyectado en el prefijo."
fi

log_success "Prefijo ${SERVER_ID} aprovisionado correctamente en ${PREFIX_PATH}"

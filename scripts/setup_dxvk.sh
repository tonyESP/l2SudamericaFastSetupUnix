#!/usr/bin/env bash
# Automates acquisition and setup of 32-bit DXVK (d3d9.dll, dxgi.dll) for Lineage 2
# Follows strict Clean Code and engineering standards.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

DXVK_VERSION="2.4"
DXVK_TARBALL="dxvk-${DXVK_VERSION}.tar.gz"
DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v${DXVK_VERSION}/${DXVK_TARBALL}"
DEST_ARCHIVE="${L2_DOWNLOADS_DIR}/${DXVK_TARBALL}"
DEST_DIR="${L2_TOOLS_DIR}/dxvk_32"

mkdir -p "${L2_DOWNLOADS_DIR}" "${DEST_DIR}"

if [[ -f "${DEST_DIR}/d3d9.dll" && -f "${DEST_DIR}/dxgi.dll" && "${1:-}" != "--force" ]]; then
    log_success "DXVK 32-bit ya está disponible en ${DEST_DIR}"
    exit 0
fi

log_info "Descargando DXVK v${DXVK_VERSION} desde GitHub..."
if [[ ! -f "${DEST_ARCHIVE}" || "${1:-}" == "--force" ]]; then
    if command -v curl >/dev/null 2>&1; then
        curl -fSL "${DXVK_URL}" -o "${DEST_ARCHIVE}"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "${DEST_ARCHIVE}" "${DXVK_URL}"
    else
        log_error "Se requiere 'curl' o 'wget' para descargar DXVK."
        exit 1
    fi
fi

log_info "Extrayendo librerías DXVK de 32 bits..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

tar -xzf "${DEST_ARCHIVE}" -C "${TMP_DIR}"

if [[ -d "${TMP_DIR}/dxvk-${DXVK_VERSION}/x32" ]]; then
    cp -f "${TMP_DIR}/dxvk-${DXVK_VERSION}/x32/d3d9.dll" "${DEST_DIR}/d3d9.dll"
    cp -f "${TMP_DIR}/dxvk-${DXVK_VERSION}/x32/dxgi.dll" "${DEST_DIR}/dxgi.dll"
    for extra_dll in d3d10core.dll d3d11.dll d3d8.dll openvr_api_dxvk.dll; do
        if [[ -f "${TMP_DIR}/dxvk-${DXVK_VERSION}/x32/${extra_dll}" ]]; then
            cp -f "${TMP_DIR}/dxvk-${DXVK_VERSION}/x32/${extra_dll}" "${DEST_DIR}/${extra_dll}"
        fi
    done
    chmod 644 "${DEST_DIR}"/*.dll
    log_success "DXVK 32-bit instalado correctamente en ${DEST_DIR}"
else
    log_error "Estructura inesperada en el archivo de DXVK."
    exit 1
fi

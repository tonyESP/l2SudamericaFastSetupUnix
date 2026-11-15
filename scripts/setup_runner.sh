#!/usr/bin/env bash
# Helper to detect or download a dedicated Wine-GE / Proton runner

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

RUNNER_DEFAULT_NAME="wine-ge-8-26"
TARGET_DIR="${L2_RUNNERS_DIR}/${RUNNER_DEFAULT_NAME}"

find_active_runner() {
    # 1. Project local runner
    if [[ -x "${L2_RUNNERS_DIR}/current/bin/wine" ]]; then
        echo "${L2_RUNNERS_DIR}/current/bin/wine"
        return 0
    fi
    if [[ -x "${TARGET_DIR}/bin/wine" ]]; then
        echo "${TARGET_DIR}/bin/wine"
        return 0
    fi

    # 2. Lutris runner if installed
    local lutris_runner
    lutris_runner=$(find "${HOME}/.local/share/lutris/runners/wine" -name "wine" -type f -executable 2>/dev/null | head -n 1 || true)
    if [[ -n "${lutris_runner}" ]]; then
        echo "${lutris_runner}"
        return 0
    fi

    # 3. System wine
    if command -v wine >/dev/null 2>&1; then
        command -v wine
        return 0
    fi

    return 1
}

download_wine_ge() {
    local release_tag="GE-Proton8-26"
    local tarball_name="wine-lutris-${release_tag}-x86_64.tar.xz"
    local url="https://github.com/GloriousEggroll/wine-ge-custom/releases/download/${release_tag}/${tarball_name}"
    local dest_archive="${L2_DOWNLOADS_DIR}/${tarball_name}"

    log_info "Descargando runner Wine-GE optimizado (${release_tag})..."
    if [[ ! -f "${dest_archive}" ]]; then
        curl -fSL "${url}" -o "${dest_archive}"
    fi

    log_info "Extrayendo en ${L2_RUNNERS_DIR}..."
    mkdir -p "${L2_RUNNERS_DIR}"
    tar -xf "${dest_archive}" -C "${L2_RUNNERS_DIR}"

    # Symlink current runner
    ln -sfn "${L2_RUNNERS_DIR}/lutris-${release_tag}-x86_64" "${L2_RUNNERS_DIR}/current"
    log_success "Runner instalado y configurado en ${L2_RUNNERS_DIR}/current"
}

if [[ "${1:-}" == "download" ]]; then
    download_wine_ge
else
    RUNNER_BIN=$(find_active_runner || true)
    if [[ -n "${RUNNER_BIN}" ]]; then
        log_success "Runner activo encontrado: ${RUNNER_BIN}"
    else
        log_warn "No se encontró ningún runner de Wine instalado."
        log_info "Ejecuta: ${0} download para descargar Wine-GE automáticamente."
    fi
fi

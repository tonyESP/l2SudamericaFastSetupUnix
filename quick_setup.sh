#!/usr/bin/env bash
# ==============================================================================
# Lineage 2 Sudamérica — Instalador y Optimizador Automático 1-Click (Linux/Unix)
# ==============================================================================
# Automatiza de punta a punta:
# 1. Comprobación de arquitectura y dependencias (i386, Wine, Vulkan)
# 2. Compilación y verificación de shims de red (l2_auth_redir.so)
# 3. Descarga y configuración de Wine-GE (GloriousEggroll) y DXVK 32-bit
# 4. Detección, extracción y normalización del cliente L2 Sudamérica
# 5. Generación de perfiles duales (Remaster Diario vs Asedio Ultra-FPS)
# 6. Aprovisionamiento de prefijos Wine 32-bit (ratón 1:1, crash-guard)
# 7. Inyección de plantillas de tuning (dxvk.conf, Option.ini, vkBasalt)
# 8. Creación de accesos directos en el menú de aplicaciones y en el escritorio
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/env.sh"

CLIENT_PATH_ARG=""
DRY_RUN=0
NON_INTERACTIVE=0
SKIP_DOWNLOAD=0

usage() {
    cat <<EOF
${C_CYAN}Instalador y Optimizador 1-Click — Lineage 2 Sudamérica (Linux/Unix)${C_RESET}

Uso: $0 [opciones]

Opciones:
  --client-path <ruta>    Ruta a archivo .rar/.zip o carpeta del cliente L2
  --dry-run               Inspecciona y valida el entorno sin modificar el sistema
  --non-interactive, -y   Ejecución desatendida con respuestas por defecto
  --skip-download         No descarga el runner ni DXVK si no están presentes
  --help, -h              Muestra esta ayuda

Ejemplos:
  $0
  $0 --client-path ~/Descargas/l2Sudamerica_fafureon_30.rar
  $0 --dry-run
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --client-path)
            CLIENT_PATH_ARG="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --non-interactive|-y)
            NON_INTERACTIVE=1
            shift
            ;;
        --skip-download)
            SKIP_DOWNLOAD=1
            shift
            ;;
        --help|-h)
            usage
            ;;
        *)
            if [[ -z "${CLIENT_PATH_ARG}" && -e "$1" ]]; then
                CLIENT_PATH_ARG="$1"
                shift
            else
                log_error "Argumento desconocido: $1"
                echo "Usa $0 --help para ver las opciones."
                exit 1
            fi
            ;;
    esac
done

echo -e "\n${C_CYAN}╔═══════════════════════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_CYAN}║     LINEAGE 2 SUDAMÉRICA — INSTALADOR Y OPTIMIZADOR 1-CLICK LINUX     ║${C_RESET}"
echo -e "${C_CYAN}╚═══════════════════════════════════════════════════════════════════════╝${C_RESET}\n"

if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Modo simulación activado. No se realizarán cambios en disco."
fi

# ------------------------------------------------------------------------------
# PASO 1: Verificación de Arquitectura y Dependencias del Sistema
# ------------------------------------------------------------------------------
log_info "Paso 1/7: Verificando dependencias del sistema y arquitectura..."

check_cmd() {
    local cmd="$1"
    local pkg_hint="${2:-$1}"
    if command -v "${cmd}" >/dev/null 2>&1; then
        echo -e "  [OK] ${cmd}"
        return 0
    else
        echo -e "  ${C_YELLOW}[FALTA]${C_RESET} ${cmd} (paquete sugerido: ${pkg_hint})"
        return 1
    fi
}

MISSING_DEPS=0
check_cmd python3 python3 || MISSING_DEPS=$((MISSING_DEPS + 1))
check_cmd curl curl || MISSING_DEPS=$((MISSING_DEPS + 1))
check_cmd tar tar || MISSING_DEPS=$((MISSING_DEPS + 1))

# Check 7z or unrar
if ! command -v 7z >/dev/null 2>&1 && ! command -v unrar >/dev/null 2>&1; then
    echo -e "  ${C_YELLOW}[FALTA]${C_RESET} 7z o unrar (paquete sugerido: p7zip-full o unrar)"
    MISSING_DEPS=$((MISSING_DEPS + 1))
else
    echo -e "  [OK] Descompresor (7z/unrar)"
fi

# Check multilib i386 if dpkg exists
if command -v dpkg >/dev/null 2>&1; then
    if dpkg --print-foreign-architectures | grep -q "i386"; then
        echo -e "  [OK] Arquitectura multiarch i386 habilitada"
    else
        echo -e "  ${C_YELLOW}[AVISO]${C_RESET} multiarch i386 no está habilitada. Recomendado: sudo dpkg --add-architecture i386"
    fi
fi

if [[ ${MISSING_DEPS} -gt 0 && ${DRY_RUN} -eq 0 ]]; then
    log_warn "Faltan ${MISSING_DEPS} dependencias en el sistema."
    if command -v apt-get >/dev/null 2>&1; then
        log_info "Puedes instalarlas con:"
        echo "  sudo dpkg --add-architecture i386 && sudo apt update"
        echo "  sudo apt install -y curl p7zip-full unrar python3 gcc gcc-multilib gamemode"
        if [[ ${NON_INTERACTIVE} -eq 0 ]]; then
            read -r -p "¿Deseas que intente instalarlas con sudo apt ahora? (s/N): " install_ans || true
            if [[ "${install_ans:-}" =~ ^[sSyY]$ ]]; then
                sudo dpkg --add-architecture i386 || true
                sudo apt-get update || true
                sudo apt-get install -y curl p7zip-full unrar python3 gcc gcc-multilib gamemode || true
            fi
        fi
    fi
fi

# ------------------------------------------------------------------------------
# PASO 2: Verificación y Compilación de Shims de Red (Anti-Lag / QoS)
# ------------------------------------------------------------------------------
log_info "Paso 2/7: Preparando shims de red (l2_auth_redir.so)..."

SHIM_SO="${L2_TOOLS_DIR}/shims/l2_auth_redir.so"
SHIM_32="${L2_TOOLS_DIR}/shims/lib/i386-linux-gnu/l2_auth_redir.so"
SHIM_64="${L2_TOOLS_DIR}/shims/lib/x86_64-linux-gnu/l2_auth_redir.so"

if [[ ${DRY_RUN} -eq 0 ]]; then
    mkdir -p "${L2_TOOLS_DIR}/shims/lib/i386-linux-gnu" "${L2_TOOLS_DIR}/shims/lib/x86_64-linux-gnu"
    
    # If gcc and gcc-multilib are present, compile for maximum reliability
    if command -v gcc >/dev/null 2>&1 && [[ -f "${L2_TOOLS_DIR}/shims/l2_auth_redir.c" ]]; then
        if gcc -m32 -shared -fPIC -O2 "${L2_TOOLS_DIR}/shims/l2_auth_redir.c" -o "${SHIM_32}" -ldl 2>/dev/null; then
            gcc -shared -fPIC -O2 "${L2_TOOLS_DIR}/shims/l2_auth_redir.c" -o "${SHIM_64}" -ldl 2>/dev/null || true
            cp -f "${SHIM_64}" "${SHIM_SO}" 2>/dev/null || cp -f "${SHIM_32}" "${SHIM_SO}" 2>/dev/null || true
            log_success "Shims de red de 32 y 64 bits compilados con éxito."
        fi
    fi

    # Fallback to precompiled shims if needed
    if [[ ! -f "${SHIM_SO}" ]]; then
        if [[ -f "${SHIM_64}" ]]; then
            cp -f "${SHIM_64}" "${SHIM_SO}"
        elif [[ -f "${SHIM_32}" ]]; then
            cp -f "${SHIM_32}" "${SHIM_SO}"
        fi
    fi
fi
log_success "Shims de red listos para enrutamiento y QuickACK."

# ------------------------------------------------------------------------------
# PASO 3: Wine Runner y DXVK 32-bit
# ------------------------------------------------------------------------------
log_info "Paso 3/7: Verificando Wine Runner y DXVK..."

RUNNER_BIN=""
if [[ -x "${L2_RUNNERS_DIR}/current/bin/wine" ]]; then
    RUNNER_BIN="${L2_RUNNERS_DIR}/current/bin/wine"
elif command -v wine >/dev/null 2>&1; then
    RUNNER_BIN=$(command -v wine)
fi

if [[ -z "${RUNNER_BIN}" ]]; then
    if [[ ${SKIP_DOWNLOAD} -eq 1 || ${DRY_RUN} -eq 1 ]]; then
        log_warn "No hay runner de Wine configurado."
    else
        log_info "Descargando Wine-GE (GloriousEggroll) optimizado..."
        "${SCRIPT_DIR}/scripts/setup_runner.sh" download
        RUNNER_BIN="${L2_RUNNERS_DIR}/current/bin/wine"
    fi
else
    log_success "Runner de Wine detectado: ${RUNNER_BIN}"
fi

# DXVK 32-bit setup
DXVK_D3D9="${L2_TOOLS_DIR}/dxvk_32/d3d9.dll"
if [[ ! -f "${DXVK_D3D9}" ]]; then
    if [[ ${SKIP_DOWNLOAD} -eq 1 || ${DRY_RUN} -eq 1 ]]; then
        log_warn "DXVK 32-bit no encontrado en tools/dxvk_32/"
    else
        log_info "Instalando DXVK 32-bit (Vulkan Direct3D9)..."
        "${SCRIPT_DIR}/scripts/setup_dxvk.sh"
    fi
else
    log_success "DXVK 32-bit detectado en tools/dxvk_32/d3d9.dll"
fi

# ------------------------------------------------------------------------------
# PASO 4: Detección, Adquisición y Normalización del Cliente L2
# ------------------------------------------------------------------------------
log_info "Paso 4/7: Comprobando cliente de Lineage 2 Sudamérica..."

OPTI_CLIENT_DIR="${L2_CLIENTS_DIR}/l2suda-optimizado"
OPTI_EXE="${OPTI_CLIENT_DIR}/system/L2.exe"
[[ ! -f "${OPTI_EXE}" ]] && OPTI_EXE="${OPTI_CLIENT_DIR}/system/l2.exe"

find_candidate_archive() {
    local candidate=""
    if [[ -n "${CLIENT_PATH_ARG}" && -e "${CLIENT_PATH_ARG}" ]]; then
        echo "${CLIENT_PATH_ARG}"
        return 0
    fi
    for f in "${L2_DOWNLOADS_DIR}"/l2Sudamerica*.rar "${L2_DOWNLOADS_DIR}"/l2*.rar "${L2_DOWNLOADS_DIR}"/*.rar "${L2_DOWNLOADS_DIR}"/*.7z "${L2_DOWNLOADS_DIR}"/*.zip "${L2_PROJECT_ROOT}"/*.rar; do
        if [[ -f "${f}" ]]; then
            echo "${f}"
            return 0
        fi
    done
    return 1
}

if [[ -f "${OPTI_EXE}" ]]; then
    log_success "Cliente base L2 Sudamérica encontrado en ${OPTI_CLIENT_DIR}"
elif [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Se verificará y extraerá el cliente en ${OPTI_CLIENT_DIR}"
else
    CANDIDATE_ARCHIVE=$(find_candidate_archive || true)
    
    if [[ -z "${CANDIDATE_ARCHIVE}" && ${NON_INTERACTIVE} -eq 0 ]]; then
        echo -e "\n${C_YELLOW}No se detectó el cliente de L2 Sudamérica en disco.${C_RESET}"
        echo "Opciones disponibles:"
        echo "1. Si ya descargaste el archivo .rar/.zip o tienes la carpeta del juego:"
        read -r -p "   Arrastra aquí el archivo o escribe su ruta (Enter para omitir): " USER_INPUT_PATH || true
        USER_INPUT_PATH=$(echo "${USER_INPUT_PATH:-}" | tr -d "'" | tr -d '"')
        if [[ -n "${USER_INPUT_PATH}" && -e "${USER_INPUT_PATH}" ]]; then
            CANDIDATE_ARCHIVE="${USER_INPUT_PATH}"
        fi
    fi

    if [[ -n "${CANDIDATE_ARCHIVE}" && -e "${CANDIDATE_ARCHIVE}" ]]; then
        log_info "Procesando cliente desde: ${CANDIDATE_ARCHIVE}"
        mkdir -p "${OPTI_CLIENT_DIR}"
        if [[ -d "${CANDIDATE_ARCHIVE}" ]]; then
            log_info "Copiando carpeta de juego..."
            cp -rn "${CANDIDATE_ARCHIVE}"/* "${OPTI_CLIENT_DIR}/" 2>/dev/null || true
        else
            log_info "Extrayendo archivo comprimido (${CANDIDATE_ARCHIVE})..."
            if command -v 7z >/dev/null 2>&1; then
                7z x -y -o"${OPTI_CLIENT_DIR}" "${CANDIDATE_ARCHIVE}" >/dev/null
            elif command -v unrar >/dev/null 2>&1; then
                unrar x -o+ "${CANDIDATE_ARCHIVE}" "${OPTI_CLIENT_DIR}/" >/dev/null
            elif command -v unzip >/dev/null 2>&1 && [[ "${CANDIDATE_ARCHIVE}" == *.zip ]]; then
                unzip -qo "${CANDIDATE_ARCHIVE}" -d "${OPTI_CLIENT_DIR}"
            fi
        fi

        # Un-nest if extracted inside a subfolder containing system/
        NESTED_SYSTEM=$(find "${OPTI_CLIENT_DIR}" -mindepth 2 -maxdepth 2 -type d -iname "system" | head -n 1 || true)
        if [[ -n "${NESTED_SYSTEM}" ]]; then
            NESTED_DIR="$(dirname "${NESTED_SYSTEM}")"
            log_info "Normalizando subdirectorio anidado: ${NESTED_DIR} -> ${OPTI_CLIENT_DIR}"
            cp -rn "${NESTED_DIR}"/* "${OPTI_CLIENT_DIR}/" 2>/dev/null || true
            rm -rf "${NESTED_DIR}"
        fi
    else
        log_warn "Cliente no encontrado. Puedes descargarlo de los enlaces oficiales:"
        echo "  • Google Drive: https://drive.google.com/file/d/1EcLm1ln28486fSbX624VxPH_8iDksHa8/view?usp=drive_link"
        echo "  • Mediafire:    https://www.mediafire.com/file/z6ja61scxvy4xmu/l2Sudamerica_fafureon_20.rar/file"
        echo "  • Sitio Web:    https://www.l2sudamerica.com/"
        echo "Una vez descargado, ejecuta: $0 --client-path <ruta_al_archivo>"
    fi
fi

# Mirror / hardlink shared heavy assets for siege and interlude profiles (0 duplicate disk space)
if [[ -d "${OPTI_CLIENT_DIR}" && -d "${OPTI_CLIENT_DIR}/system" && ${DRY_RUN} -eq 0 ]]; then
    # Remove incompatible legacy d3d9 wrapper if present
    rm -f "${OPTI_CLIENT_DIR}/system/d3d9_R21B.dll"
    
    # Prepare l2suda-asedio
    ASEDIO_DIR="${L2_CLIENTS_DIR}/l2suda-asedio"
    if [[ ! -d "${ASEDIO_DIR}/system" ]]; then
        log_info "Creando perfil de Asedio (l2suda-asedio) mediante enlaces duros instantáneos..."
        mkdir -p "${ASEDIO_DIR}"
        cp -al "${OPTI_CLIENT_DIR}"/* "${ASEDIO_DIR}/" 2>/dev/null || cp -rn "${OPTI_CLIENT_DIR}"/* "${ASEDIO_DIR}/" 2>/dev/null || true
        # Ensure system directory in asedio is independent
        rm -rf "${ASEDIO_DIR}/system"
        cp -r "${OPTI_CLIENT_DIR}/system" "${ASEDIO_DIR}/system"
    fi

    # Prepare l2sudamerica-interlude fallback
    INTERLUDE_DIR="${L2_CLIENTS_DIR}/l2sudamerica-interlude"
    if [[ ! -d "${INTERLUDE_DIR}/system" ]]; then
        log_info "Creando perfil fallback (l2sudamerica-interlude)..."
        mkdir -p "${INTERLUDE_DIR}"
        cp -al "${OPTI_CLIENT_DIR}"/* "${INTERLUDE_DIR}/" 2>/dev/null || cp -rn "${OPTI_CLIENT_DIR}"/* "${INTERLUDE_DIR}/" 2>/dev/null || true
        rm -rf "${INTERLUDE_DIR}/system"
        cp -r "${OPTI_CLIENT_DIR}/system" "${INTERLUDE_DIR}/system"
    fi
fi

# ------------------------------------------------------------------------------
# PASO 5: Aprovisionamiento de Prefijos Wine (32-bit + Ratón 1:1 + Crash-Guard)
# ------------------------------------------------------------------------------
log_info "Paso 5/7: Aprovisionando prefijos Wine aislados..."

if [[ ${DRY_RUN} -eq 0 ]]; then
    for s_id in l2suda-optimizado l2suda-asedio; do
        if [[ ! -d "${L2_PREFIXES_DIR}/${s_id}/drive_c" ]]; then
            log_info "Aprovisionando prefijo para '${s_id}'..."
            "${SCRIPT_DIR}/scripts/provision_prefix.sh" "${s_id}" || {
                log_warn "Advertencia durante aprovisionamiento de ${s_id}, continuando..."
            }
        else
            log_success "Prefijo Wine para '${s_id}' ya aprovisionado."
        fi
    done
fi

# ------------------------------------------------------------------------------
# PASO 6: Inyección de Tuning y Plantillas Gráficas Calibradas
# ------------------------------------------------------------------------------
log_info "Paso 6/7: Inyectando perfiles gráficos (Remaster vs Asedios)..."

if [[ ${DRY_RUN} -eq 0 ]]; then
    for s_id in l2suda-optimizado l2suda-asedio; do
        if [[ -d "${L2_CLIENTS_DIR}/${s_id}/system" ]]; then
            "${SCRIPT_DIR}/scripts/apply_tuning.sh" "${s_id}" --force
        fi
    done
fi

# ------------------------------------------------------------------------------
# PASO 7: Creación de Accesos Directos en el Sistema (.desktop)
# ------------------------------------------------------------------------------
log_info "Paso 7/7: Instalando lanzadores en el menú de aplicaciones y escritorio..."

if [[ ${DRY_RUN} -eq 0 ]]; then
    APPS_DIR="${HOME}/.local/share/applications"
    mkdir -p "${APPS_DIR}"
    
    for dt in "${L2_CONFIG_DIR}"/l2suda-*.desktop; do
        if [[ -f "${dt}" ]]; then
            dest_file="${APPS_DIR}/$(basename "${dt}")"
            sed "s|/mnt/disk4u/L2|${L2_PROJECT_ROOT}|g" "${dt}" > "${dest_file}"
            chmod +x "${dest_file}"
            log_success "Lanzador instalado: ${dest_file}"
        fi
    done

    # Also install on Desktop if Desktop folder exists
    for desktop_dir in "${HOME}/Desktop" "${HOME}/Escritorio"; do
        if [[ -d "${desktop_dir}" ]]; then
            for dt in "${L2_CONFIG_DIR}"/l2suda-*.desktop; do
                if [[ -f "${dt}" ]]; then
                    dest_file="${desktop_dir}/$(basename "${dt}")"
                    sed "s|/mnt/disk4u/L2|${L2_PROJECT_ROOT}|g" "${dt}" > "${dest_file}"
                    chmod +x "${dest_file}"
                fi
            done
            log_success "Accesos directos creados en el Escritorio (${desktop_dir})"
            break
        fi
    done

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "${APPS_DIR}" 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# Resumen y Diagnóstico Final
# ------------------------------------------------------------------------------
echo -e "\n${C_GREEN}═══════════════════════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_GREEN}  ¡INSTALACIÓN Y OPTIMIZACIÓN COMPLETADAS CON ÉXITO!                   ${C_RESET}"
echo -e "${C_GREEN}═══════════════════════════════════════════════════════════════════════${C_RESET}\n"

if [[ ${DRY_RUN} -eq 0 ]]; then
    "${SCRIPT_DIR}/scripts/l2_ctl.sh" doctor || true
fi

echo -e "\n${C_CYAN}Cómo jugar:${C_RESET}"
echo -e "  1. Desde el Menú de Aplicaciones de tu Linux: busca ${C_GREEN}l2suda-optimizado${C_RESET}"
echo -e "  2. O directamente desde terminal:"
echo -e "     ${C_CYAN}./scripts/l2_ctl.sh run l2suda-optimizado${C_RESET}  (Juego diario Remaster 60 FPS)"
echo -e "     ${C_CYAN}./scripts/l2_ctl.sh run l2suda-asedio${C_RESET}      (Asedios y Mass PvP Ultra-FPS)"
echo -e "     ${C_CYAN}./scripts/l2_ctl.sh update${C_RESET}                 (Sincronizar parches oficiales)\n"

#!/usr/bin/env bash
# Injects fine-tuning configuration into a Lineage 2 client system directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

SERVER_ID=""
FORCE_TUNING=0
for arg in "$@"; do
    case "${arg}" in
        --force|-f) FORCE_TUNING=1 ;;
        *) [[ -z "${SERVER_ID}" ]] && SERVER_ID="${arg}" ;;
    esac
done

if [[ -z "${SERVER_ID}" ]]; then
    log_error "Uso: $0 <server_id> [--force]"
    exit 1
fi

CLIENT_SYSTEM_DIR="${L2_CLIENTS_DIR}/${SERVER_ID}/system"

if [[ ! -d "${CLIENT_SYSTEM_DIR}" ]]; then
    log_warn "El directorio '${CLIENT_SYSTEM_DIR}' aún no existe."
    log_info "Crea la carpeta o descomprime el cliente antes de aplicar el tuning."
    mkdir -p "${CLIENT_SYSTEM_DIR}"
fi

log_info "Aplicando fine-tuning a: ${SERVER_ID}..."

DXVK_TEMPLATE="${L2_CONFIG_DIR}/dxvk.conf.template"
OPT_TEMPLATE="${L2_CONFIG_DIR}/Option.ini.template"
case "${SERVER_ID}" in
    l2suda-asedio)
        [[ -f "${L2_CONFIG_DIR}/dxvk.siege.conf.template" ]] && DXVK_TEMPLATE="${L2_CONFIG_DIR}/dxvk.siege.conf.template"
        [[ -f "${L2_CONFIG_DIR}/Option.siege.ini.template" ]] && OPT_TEMPLATE="${L2_CONFIG_DIR}/Option.siege.ini.template"
        ;;
    l2suda-optimizado)
        [[ -f "${L2_CONFIG_DIR}/Option.optimized.ini.template" ]] && OPT_TEMPLATE="${L2_CONFIG_DIR}/Option.optimized.ini.template"
        ;;
esac

# 1. Inyectar dxvk.conf
cp "${DXVK_TEMPLATE}" "${CLIENT_SYSTEM_DIR}/dxvk.conf"
log_success "dxvk.conf ($(basename "${DXVK_TEMPLATE}")) inyectado en ${CLIENT_SYSTEM_DIR}/dxvk.conf"

# 2. Inyectar Option.ini (nuevo o con --force respaldando el anterior)
if [[ ! -f "${CLIENT_SYSTEM_DIR}/Option.ini" || "${FORCE_TUNING}" == "1" ]]; then
    if [[ -f "${CLIENT_SYSTEM_DIR}/Option.ini" ]]; then
        cp -p "${CLIENT_SYSTEM_DIR}/Option.ini" "${CLIENT_SYSTEM_DIR}/Option.ini.bak-pre-tuning"
    fi
    cp "${OPT_TEMPLATE}" "${CLIENT_SYSTEM_DIR}/Option.ini"
    log_success "Option.ini ($(basename "${OPT_TEMPLATE}")) inyectado."
else
    log_info "Option.ini existente detectado; se mantiene para no sobrescribir keybindings (usa --force para reemplazar)."
    if ! grep -q "UseAGP" "${CLIENT_SYSTEM_DIR}/Option.ini"; then
        sed -i '/\[Video\]/a UseAGP=False\r' "${CLIENT_SYSTEM_DIR}/Option.ini"
        log_success "Directiva UseAGP=False inyectada en Option.ini existente."
    fi
fi

# 3. Provisionar vkBasalt.conf si existe tools/vkbasalt (o falta / apunta a otra ruta)
if [[ -d "${L2_TOOLS_DIR}/vkbasalt" && -f "${L2_CONFIG_DIR}/vkBasalt.conf.template" ]]; then
    if [[ ! -f "${L2_TOOLS_DIR}/vkbasalt/vkBasalt.conf" || "${FORCE_TUNING}" == "1" ]] || ! grep -q "${L2_PROJECT_ROOT}/tools/vkbasalt" "${L2_TOOLS_DIR}/vkbasalt/vkBasalt.conf" 2>/dev/null; then
        sed "s|/mnt/disk4u/L2|${L2_PROJECT_ROOT}|g" "${L2_CONFIG_DIR}/vkBasalt.conf.template" > "${L2_TOOLS_DIR}/vkbasalt/vkBasalt.conf"
        log_success "vkBasalt.conf generado desde plantilla en ${L2_TOOLS_DIR}/vkbasalt/vkBasalt.conf"
    fi
fi

log_success "Fine-tuning completado para ${SERVER_ID}."

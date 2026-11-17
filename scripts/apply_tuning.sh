#!/usr/bin/env bash
# Injects fine-tuning configuration into a Lineage 2 client system directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

SERVER_ID="${1:-}"

if [[ -z "${SERVER_ID}" ]]; then
    log_error "Uso: $0 <server_id>"
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
    l2sudamerica-siege)
        [[ -f "${L2_CONFIG_DIR}/dxvk.siege.conf.template" ]] && DXVK_TEMPLATE="${L2_CONFIG_DIR}/dxvk.siege.conf.template"
        [[ -f "${L2_CONFIG_DIR}/Option.siege.ini.template" ]] && OPT_TEMPLATE="${L2_CONFIG_DIR}/Option.siege.ini.template"
        ;;
    l2sudamerica-optimized)
        [[ -f "${L2_CONFIG_DIR}/Option.optimized.ini.template" ]] && OPT_TEMPLATE="${L2_CONFIG_DIR}/Option.optimized.ini.template"
        ;;
esac

# 1. Inyectar dxvk.conf
cp "${DXVK_TEMPLATE}" "${CLIENT_SYSTEM_DIR}/dxvk.conf"
log_success "dxvk.conf ($(basename "${DXVK_TEMPLATE}")) inyectado en ${CLIENT_SYSTEM_DIR}/dxvk.conf"

# 2. Inyectar Option.ini (si no existe uno personalizado o forzar)
if [[ ! -f "${CLIENT_SYSTEM_DIR}/Option.ini" ]]; then
    cp "${OPT_TEMPLATE}" "${CLIENT_SYSTEM_DIR}/Option.ini"
    log_success "Option.ini ($(basename "${OPT_TEMPLATE}")) inyectado."
else
    log_info "Option.ini existente detectado; se mantiene para no sobrescribir keybindings."
    if ! grep -q "UseAGP" "${CLIENT_SYSTEM_DIR}/Option.ini"; then
        sed -i '/\[Video\]/a UseAGP=False' "${CLIENT_SYSTEM_DIR}/Option.ini"
        log_success "Directiva UseAGP=False inyectada en Option.ini existente."
    fi
fi

# 3. Provisionar vkBasalt.conf si existe tools/vkbasalt pero aún no hay config local
if [[ -d "${L2_TOOLS_DIR}/vkbasalt" && ! -f "${L2_TOOLS_DIR}/vkbasalt/vkBasalt.conf" && -f "${L2_CONFIG_DIR}/vkBasalt.conf.template" ]]; then
    sed "s|/mnt/disk4u/L2|${L2_PROJECT_ROOT}|g" "${L2_CONFIG_DIR}/vkBasalt.conf.template" > "${L2_TOOLS_DIR}/vkbasalt/vkBasalt.conf"
    log_success "vkBasalt.conf generado desde plantilla en ${L2_TOOLS_DIR}/vkbasalt/vkBasalt.conf"
fi

log_success "Fine-tuning completado para ${SERVER_ID}."

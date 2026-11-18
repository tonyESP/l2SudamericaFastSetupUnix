#!/usr/bin/env bash
# ==============================================================================
# Lineage 2 Transatlantic Relay Controller (Linux Client Side)
# ==============================================================================
# Administra el túnel WireGuard de baja latencia hacia el relay de São Paulo.
# Garantiza Split-Tunneling estricto (AllowedIPs = 45.235.99.29/32) para no
# interferir con el resto del tráfico del sistema.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RELAY_CONF="${PROJECT_ROOT}/config/relay/wg-l2suda.conf"
GAME_SERVER_IP="45.235.99.29"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat << EOF
Uso: $0 <comando> [argumentos]

Comandos disponibles:
  status               Muestra el estado actual del túnel y la ruta activa hacia el servidor de L2.
  up                   Levanta el túnel WireGuard Split-Tunnel hacia el relay.
  down                 Baja el túnel y restaura la ruta directa por tu ISP.
  test <ip_vps>        Mide la latencia directa contra el VPS de São Paulo y estima la mejora.
  doctor               Comprueba dependencias locales y soporte del kernel de WireGuard.

Archivos:
  Configuración:       ${RELAY_CONF}
  Plantilla:           ${PROJECT_ROOT}/config/relay/wg-l2suda.conf.template
  Script de VPS:       ${PROJECT_ROOT}/tools/relay/setup_vps.sh
EOF
    exit 1
}

cmd_doctor() {
    log_info "Auditando dependencias de red en el sistema local..."
    local ok=true

    if command -v ip >/dev/null 2>&1; then
        log_ok "Herramienta iproute2 presente."
    else
        log_err "Falta iproute2 (ip)."
        ok=false
    fi

    if command -v wg-quick >/dev/null 2>&1; then
        log_ok "Herramienta wg-quick (wireguard-tools) instalada."
    else
        log_warn "wg-quick no está instalado. Instálalo con: sudo apt install wireguard-tools"
        ok=false
    fi

    if command -v ping >/dev/null 2>&1; then
        log_ok "Herramienta ping presente."
    else
        log_err "Falta herramienta ping."
        ok=false
    fi

    if [[ -f "${RELAY_CONF}" ]]; then
        log_ok "Archivo de configuración encontrado: ${RELAY_CONF}"
    else
        log_warn "No existe ${RELAY_CONF}. Sigue la guía en docs/ROUTING_RELAY_GUIDE.md para generarlo."
    fi

    if [[ "${ok}" == "true" ]]; then
        log_ok "Todo listo para usar el relay."
    else
        log_warn "Se detectaron avisos previos a la conexión."
    fi
}

cmd_status() {
    log_info "Comprobando estado del enrutamiento hacia L2 Sudamérica (${GAME_SERVER_IP})..."
    local route_out
    route_out=$(ip route get "${GAME_SERVER_IP}" 2>/dev/null || true)

    if [[ -z "${route_out}" ]]; then
        log_err "No se pudo resolver la ruta hacia ${GAME_SERVER_IP}."
        return 1
    fi

    echo -e "${CYAN}Ruta activa en el kernel:${NC}"
    echo "  ${route_out}"

    if echo "${route_out}" | grep -qE "wg-l2suda|wg0"; then
        echo -e "${GREEN}ESTADO: TÚNEL ACTIVO (El juego está saliendo por el Relay de São Paulo)${NC}"
    else
        echo -e "${YELLOW}ESTADO: RUTA DIRECTA (El juego está saliendo por el ISP normal de casa)${NC}"
    fi

    echo ""
    log_info "Comprobando latencia actual hacia el GameServer (${GAME_SERVER_IP})..."
    if ping -c 3 -W 2 "${GAME_SERVER_IP}" >/dev/null 2>&1; then
        ping -c 3 -W 2 "${GAME_SERVER_IP}" | tail -n 2
    else
        log_warn "El servidor no respondió a ICMP ping (normal si tiene firewall anti-DDoS)."
    fi
}

cmd_up() {
    if [[ ! -f "${RELAY_CONF}" ]]; then
        log_err "No se encontró el archivo de configuración: ${RELAY_CONF}"
        log_info "Copia la configuración generada por setup_vps.sh en ${RELAY_CONF}"
        exit 1
    fi

    if ! command -v wg-quick >/dev/null 2>&1; then
        log_err "wg-quick no está instalado. Instálalo con: sudo apt install wireguard-tools"
        exit 1
    fi

    log_info "Levantando túnel WireGuard Split-Tunnel..."
    sudo wg-quick up "${RELAY_CONF}"
    log_ok "Túnel levantado con éxito."
    cmd_status
}

cmd_down() {
    if ! command -v wg-quick >/dev/null 2>&1; then
        log_err "wg-quick no está instalado."
        exit 1
    fi

    log_info "Bajando túnel WireGuard y restaurando ruta directa del ISP..."
    sudo wg-quick down "${RELAY_CONF}" || sudo wg-quick down wg-l2suda || true
    log_ok "Túnel cerrado. Ruta directa restaurada."
    cmd_status
}

cmd_test() {
    local target_ip="${1:-}"
    if [[ -z "${target_ip}" ]]; then
        log_err "Debes especificar la IP pública del VPS de São Paulo."
        echo "Ejemplo: $0 test 123.45.67.89"
        exit 1
    fi

    log_info "Midiendo RTT directo desde España hacia el VPS (${target_ip})..."
    local ping_res
    if ping_res=$(ping -c 4 -W 2 "${target_ip}" 2>/dev/null); then
        echo "${ping_res}" | tail -n 2
        local avg_rtt
        avg_rtt=$(echo "${ping_res}" | tail -n 1 | awk -F'/' '{print $5}')
        log_ok "Ping promedio al VPS: ${avg_rtt} ms"
        if [[ -n "${avg_rtt}" ]]; then
            local estimated
            estimated=$(awk "BEGIN {print ${avg_rtt} + 30.0}")
            echo ""
            echo -e "${CYAN}======================================================${NC}"
            echo -e " Latencia estimada final al GameServer de Buenos Aires: ${GREEN}~${estimated} ms${NC}"
            echo -e " Latencia actual sin relay (vía Miami):                 ${YELLOW}~262.0 ms${NC}"
            echo -e " Ahorro potencial de ping:                             ${GREEN}~$(( 262 - ${avg_rtt%.*} - 30 )) ms menos${NC}"
            echo -e "${CYAN}======================================================${NC}"
        fi
    else
        log_err "No se pudo hacer ping a ${target_ip}. Verifica que el VPS permita tráfico ICMP."
    fi
}

case "${1:-}" in
    status)
        cmd_status
        ;;
    up)
        cmd_up
        ;;
    down)
        cmd_down
        ;;
    test)
        shift
        cmd_test "$@"
        ;;
    doctor)
        cmd_doctor
        ;;
    *)
        usage
        ;;
esac

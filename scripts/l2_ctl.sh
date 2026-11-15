#!/usr/bin/env bash
# Main Orchestration CLI for Lineage 2 Linux Engineering Project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

cmd_list() {
    echo -e "${C_CYAN}=== SERVIDORES CONFIGURADOS EN EL BANCO DE PRUEBAS ===${C_RESET}\n"
    python3 -c '
import json, os

config_path = "'"${L2_CONFIG_DIR}/servers.json"'"
project_root = "'"${L2_PROJECT_ROOT}"'"

with open(config_path) as f:
    data = json.load(f)

h_id, h_chronicle, h_rates, h_client, h_prefix = "ID", "CRONICA", "RATES", "CLIENTE", "PREFIJO"
print(f"{h_id:<20} {h_chronicle:<14} {h_rates:<12} {h_client:<12} {h_prefix:<12}")
print("-" * 72)

for s_id, s in data["servers"].items():
    client_path = os.path.join(project_root, s["client_dir"])
    prefix_path = os.path.join(project_root, s["prefix_dir"])
    
    client_status = "✅ OK" if os.path.isdir(client_path) and os.listdir(client_path) else "❌ Falta"
    prefix_status = "✅ Listo" if os.path.isdir(prefix_path) and os.path.isfile(os.path.join(prefix_path, "system.reg")) else "❌ No inic."
    rates = s["rates"].get("exp", "N/A")
    chronicle = s.get("chronicle", "N/A")

    print(f"{s_id:<20} {chronicle:<14} {rates:<12} {client_status:<12} {prefix_status:<12}")
'
    echo ""
}

cmd_doctor() {
    echo -e "${C_CYAN}=== DIAGNÓSTICO DE INGENIERÍA DEL SISTEMA ===${C_RESET}\n"
    
    # OS & Kernel
    echo -n "Sistema Operativo: "
    grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"'
    echo -n "Kernel: "
    uname -r

    # GPU
    echo -n "GPU NVIDIA: "
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
    else
        echo -e "${C_RED}No detectada${C_RESET}"
    fi

    # Vulkan
    echo -n "Soporte Vulkan: "
    if command -v vulkaninfo >/dev/null 2>&1; then
        echo -e "${C_GREEN}Disponible (Vulkan 1.3)${C_RESET}"
    else
        echo -e "${C_YELLOW}vulkaninfo no encontrado${C_RESET}"
    fi

    # Runner
    echo -n "Runner Wine activo: "
    local runner
    runner=$("${SCRIPT_DIR}/setup_runner.sh" 2>/dev/null | grep "Runner activo" || true)
    if [[ -n "${runner}" ]]; then
        echo -e "${C_GREEN}${runner}${C_RESET}"
    else
        echo -e "${C_YELLOW}Ninguno (ejecuta './scripts/setup_runner.sh download')${C_RESET}"
    fi

    # Espacio en disco
    echo -n "Espacio disponible en proyecto: "
    df -h "${L2_PROJECT_ROOT}" | awk 'NR==2 {print $4}'
    echo ""
}

cmd_setup() {
    local s_id="${1:-}"
    if [[ -z "${s_id}" ]]; then
        log_error "Debes especificar un ID de servidor."
        cmd_list
        exit 1
    fi

    "${SCRIPT_DIR}/provision_prefix.sh" "${s_id}"
    "${SCRIPT_DIR}/apply_tuning.sh" "${s_id}"
    log_success "Entorno para '${s_id}' completamente preparado."
}

cmd_run() {
    local s_id="${1:-}"
    if [[ -z "${s_id}" ]]; then
        log_error "Debes especificar un ID de servidor a ejecutar."
        cmd_list
        exit 1
    fi

    local client_system_dir="${L2_CLIENTS_DIR}/${s_id}/system"
    local l2_exe="${client_system_dir}/l2.exe"
    local prefix_path="${L2_PREFIXES_DIR}/${s_id}"

    if [[ ! -f "${l2_exe}" ]]; then
        log_error "No se encuentra el ejecutable: ${l2_exe}"
        log_info "Descomprime el cliente del juego dentro de: ${L2_CLIENTS_DIR}/${s_id}/"
        exit 1
    fi

    local runner_bin
    if [[ -x "${L2_RUNNERS_DIR}/current/bin/wine" ]]; then
        runner_bin="${L2_RUNNERS_DIR}/current/bin/wine"
    elif command -v wine >/dev/null 2>&1; then
        runner_bin=$(command -v wine)
    else
        log_error "No se encontró runner de Wine."
        exit 1
    fi

    export WINE="${runner_bin}"
    export WINEPREFIX="${prefix_path}"
    export DXVK_CONFIG_FILE="${client_system_dir}/dxvk.conf"

    log_info "Iniciando Lineage 2 [${s_id}] con aceleración NVIDIA Turing..."
    cd "${client_system_dir}"
    "${WINE}" "${l2_exe}"
}

usage() {
    echo "Uso: $0 {list|doctor|setup <server_id>|run <server_id>}"
    echo ""
    echo "Comandos:"
    echo "  list               Lista los servidores y el estado de clientes y prefijos"
    echo "  doctor             Verifica hardware, controladores y dependencias de ejecución"
    echo "  setup <server_id>  Aprovisiona de forma desatendida el prefijo Wine y aplica el fine-tuning"
    echo "  run <server_id>    Lanza el juego con aceleración NVIDIA y DXVK"
    echo ""
}

case "${1:-}" in
    list)   cmd_list ;;
    doctor) cmd_doctor ;;
    setup)  shift; cmd_setup "$@" ;;
    run)    shift; cmd_run "$@" ;;
    *)      usage ;;
esac

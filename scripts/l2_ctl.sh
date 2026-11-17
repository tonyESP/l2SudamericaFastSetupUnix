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
    exe_path = os.path.join(project_root, s["client_dir"], s.get("executable", "system/l2.exe"))
    
    client_status = "✅ OK" if os.path.isfile(exe_path) else "❌ Falta"
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

    local cfg_json
    cfg_json=$(python3 -c '
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    srv = json.load(f)["servers"].get(sys.argv[2])
if not srv:
    sys.exit(1)
proxy = srv.get("auth_proxy") or {}
print(srv.get("executable", "system/l2.exe"))
print(srv.get("runner", ""))
print(proxy.get("host", ""))
print(proxy.get("port", 2106))
print("1" if srv.get("dxvk") else "0")
print("1" if srv.get("mangohud") else "0")
print("1" if srv.get("wine_esync") else "0")
print("1" if srv.get("wine_fsync") else "0")
print("1" if srv.get("nvidia_af_16x") else "0")
print("1" if srv.get("gamemode") else "0")
print("1" if srv.get("cpu_pinning") else "0")
print("1" if srv.get("tcp_nodelay") else "0")
print("1" if srv.get("ram_prewarm") else "0")
print("1" if srv.get("vkbasalt") else "0")
' "${L2_CONFIG_DIR}/servers.json" "${s_id}") || {
        log_error "Servidor no encontrado en servers.json: ${s_id}"
        exit 1
    }

    local exe_rel runner_name proxy_host proxy_port opt_dxvk opt_mangohud opt_esync opt_fsync opt_af16x opt_gamemode opt_cpu_pinning opt_tcp_nodelay opt_ram_prewarm opt_vkbasalt
    {
        read -r exe_rel
        read -r runner_name
        read -r proxy_host
        read -r proxy_port
        read -r opt_dxvk
        read -r opt_mangohud
        read -r opt_esync
        read -r opt_fsync
        read -r opt_af16x
        read -r opt_gamemode
        read -r opt_cpu_pinning
        read -r opt_tcp_nodelay
        read -r opt_ram_prewarm
        read -r opt_vkbasalt
    } <<< "${cfg_json}"

    local client_dir="${L2_CLIENTS_DIR}/${s_id}"
    local client_system_dir="${client_dir}/system"
    local l2_exe="${client_dir}/${exe_rel}"
    local prefix_path="${L2_PREFIXES_DIR}/${s_id}"

    if [[ ! -f "${l2_exe}" ]]; then
        log_error "No se encuentra el ejecutable: ${l2_exe}"
        log_info "Descomprime el cliente del juego dentro de: ${client_dir}/"
        exit 1
    fi

    local runner_bin
    if [[ -n "${runner_name}" && -x "${L2_RUNNERS_DIR}/${runner_name}/bin/wine" ]]; then
        runner_bin="${L2_RUNNERS_DIR}/${runner_name}/bin/wine"
    elif [[ -x "${L2_RUNNERS_DIR}/current/bin/wine" ]]; then
        runner_bin="${L2_RUNNERS_DIR}/current/bin/wine"
    elif command -v wine >/dev/null 2>&1; then
        runner_bin=$(command -v wine)
    else
        log_error "No se encontró runner de Wine."
        exit 1
    fi

    _L2_AUTH_PROXY_PID=""
    _L2_PREWARM_PID=""
    _L2_NETLOG_PID=""
    local _netlog_file="${L2_PROJECT_ROOT}/net_telemetry.log"
    cleanup_run() {
        for _pid in "${_L2_AUTH_PROXY_PID:-}" "${_L2_PREWARM_PID:-}" "${_L2_NETLOG_PID:-}"; do
            if [[ -n "${_pid}" ]] && kill -0 "${_pid}" 2>/dev/null; then
                kill "${_pid}" 2>/dev/null || true
                wait "${_pid}" 2>/dev/null || true
            fi
        done
        if [[ -f "${_netlog_file}" ]]; then
            tail -n 200 "${_netlog_file}" > "${_netlog_file}.tmp" 2>/dev/null && mv -f "${_netlog_file}.tmp" "${_netlog_file}" || true
        fi
    }
    trap cleanup_run EXIT

    local has_active_l2=0
    if command -v pgrep >/dev/null 2>&1 && pgrep -fi '[/\\]L2\.exe([[:space:]]|$)' >/dev/null 2>&1; then
        has_active_l2=1
    fi

    if command -v ss >/dev/null 2>&1; then
        (
            _sleep_pid=""
            trap '[[ -n "${_sleep_pid}" ]] && kill "${_sleep_pid}" 2>/dev/null || true; exit 0' TERM INT
            while true; do
                sleep 30 &
                _sleep_pid=$!
                wait "${_sleep_pid}" 2>/dev/null || exit 0
                _sleep_pid=""
                snap=$(ss -tin state established '( dport = :7777 )' 2>/dev/null | grep -Ev '^(State|Recv-Q)' || true)
                if [[ -n "${snap}" ]]; then
                    {
                        printf '[%s] [%s]\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${s_id}"
                        printf '%s\n' "${snap}"
                    } >> "${_netlog_file}"
                fi
            done
        ) &
        _L2_NETLOG_PID=$!
    fi

    if [[ "${opt_ram_prewarm}" == "1" ]]; then
        if [[ "${has_active_l2}" == "1" ]]; then
            log_info "RAM Page-Cache ya caliente por instancia activa."
        else
            (
                for d in animations systextures textures staticmeshes maps; do
                    if [[ -d "${client_dir}/${d}" ]]; then
                        find "${client_dir}/${d}" -type f -exec cat {} + > /dev/null 2>&1 || true
                    fi
                done
            ) &
            _L2_PREWARM_PID=$!
            renice -n 19 -p "${_L2_PREWARM_PID}" >/dev/null 2>&1 || true
            ionice -c 3 -p "${_L2_PREWARM_PID}" >/dev/null 2>&1 || true
            log_info "RAM Page-Cache Pre-Warm activo en segundo plano."
        fi
    fi

    if [[ -n "${proxy_host}" ]]; then
        local listen_port="${L2_AUTH_PROXY_PORT:-21060}"
        if [[ -z "${L2_AUTH_PROXY_PORT:-}" ]] && command -v ss >/dev/null 2>&1; then
            while ss -tln 2>/dev/null | grep -qE ":${listen_port}[[:space:]]"; do
                listen_port=$((listen_port + 1))
            done
        fi
        local shim_so="${L2_PROJECT_ROOT}/tools/shims/l2_auth_redir.so"
        local shim_32="${L2_PROJECT_ROOT}/tools/shims/lib/i386-linux-gnu/l2_auth_redir.so"
        local shim_64="${L2_PROJECT_ROOT}/tools/shims/lib/x86_64-linux-gnu/l2_auth_redir.so"
        if [[ ! -f "${shim_so}" ]]; then
            log_error "Falta shim de red: ${shim_so}"
            exit 1
        fi
        python3 "${SCRIPT_DIR}/l2_auth_proxy.py" \
            --listen-port "${listen_port}" \
            --target-host "${proxy_host}" \
            --target-port "${proxy_port}" &
        _L2_AUTH_PROXY_PID=$!
        export L2_AUTH_PROXY_PORT="${listen_port}"
        export L2_AUTH_TARGET_PORT="${proxy_port}"
        if [[ -f "${shim_32}" && -f "${shim_64}" ]]; then
            export LD_PRELOAD="${L2_PROJECT_ROOT}/tools/shims/\$LIB/l2_auth_redir.so${LD_PRELOAD:+:${LD_PRELOAD}}"
        else
            export LD_PRELOAD="${shim_so}${LD_PRELOAD:+:${LD_PRELOAD}}"
        fi
        log_info "Auth relay activo en 127.0.0.1:${listen_port} -> ${proxy_host}:${proxy_port}"
    fi

    if [[ -f "${client_system_dir}/Option.ini" ]]; then
        sed -i -E 's/^UseAGP=.*/UseAGP=False\r/; s/^GPUAnimation=.*/GPUAnimation=False\r/; s/^PostProc=.*/PostProc=0\r/; s/^StartupFullScreen=.*/StartupFullScreen=False\r/' "${client_system_dir}/Option.ini"
    fi

    export WINE="${runner_bin}"
    export WINEPREFIX="${prefix_path}"
    export DXVK_CONFIG_FILE="${client_system_dir}/dxvk.conf"
    export WINEDEBUG="${WINEDEBUG:--all}"
    export __GL_THREADED_OPTIMIZATIONS="${__GL_THREADED_OPTIMIZATIONS:-1}"
    export PULSE_LATENCY_MSEC="${PULSE_LATENCY_MSEC:-60}"

    if [[ "${opt_tcp_nodelay}" == "1" ]]; then
        export L2_TCP_NODELAY=1
        log_info "Red TCP: TCP_NODELAY + QUICKACK + Thin-Stream + Wi-Fi QoS (DSCP EF) activos por socket."
    fi
    if [[ "${opt_esync}" == "1" ]]; then
        export WINEESYNC=1
        export STAGING_SHARED_MEMORY=1
    fi
    if [[ "${opt_fsync}" == "1" ]]; then
        export WINEFSYNC=1
    fi
    if [[ "${opt_af16x}" == "1" ]]; then
        export __GL_SHADER_DISK_CACHE=1
        export __GL_SHADER_DISK_CACHE_PATH="${L2_TOOLS_DIR}/dxvk_cache"
        if [[ "${opt_dxvk}" != "1" ]]; then
            export __GL_Aniso=16
        fi
    fi

    if [[ "${opt_dxvk}" == "1" && -f "${L2_TOOLS_DIR}/dxvk_32/d3d9.dll" ]]; then
        if [[ ! -f "${client_system_dir}/d3d9.dll" ]] || ! cmp -s "${L2_TOOLS_DIR}/dxvk_32/d3d9.dll" "${client_system_dir}/d3d9.dll"; then
            cp -f "${L2_TOOLS_DIR}/dxvk_32/d3d9.dll" "${client_system_dir}/d3d9.dll"
        fi
        if [[ -f "${L2_TOOLS_DIR}/dxvk_32/dxgi.dll" ]]; then
            if [[ ! -f "${client_system_dir}/dxgi.dll" ]] || ! cmp -s "${L2_TOOLS_DIR}/dxvk_32/dxgi.dll" "${client_system_dir}/dxgi.dll"; then
                cp -f "${L2_TOOLS_DIR}/dxvk_32/dxgi.dll" "${client_system_dir}/dxgi.dll"
            fi
        fi
        export DXVK_STATE_CACHE_PATH="${L2_TOOLS_DIR}/dxvk_cache"
        export WINEDLLOVERRIDES="d3d9=n,b;dxgi=n,b${WINEDLLOVERRIDES:+;${WINEDLLOVERRIDES}}"
        log_info "Backend gráfico: DXVK (Vulkan) + State Cache activo."
    fi

    local -a launch_prefix=()
    if [[ "${opt_cpu_pinning}" == "1" ]] && command -v lscpu >/dev/null 2>&1; then
        local phys_cpus phys_count cpu_slot="primarios"
        if [[ "${has_active_l2}" == "1" ]]; then
            phys_cpus=$(lscpu -p=CPU,CORE | grep -v '^#' | awk -F, 'seen[$2]++ == 1 {printf "%s%s", (c++?",":""), $1}')
            cpu_slot="secundarios (dual-box SMT)"
        fi
        if [[ -z "${phys_cpus:-}" ]]; then
            phys_cpus=$(lscpu -p=CPU,CORE | grep -v '^#' | awk -F, '!seen[$2]++ {printf "%s%s", (c++?",":""), $1}')
            cpu_slot="primarios"
        fi
        phys_count=$(awk -F, '{print NF}' <<< "${phys_cpus}")
        if [[ -n "${phys_cpus}" && "${phys_count}" -gt 0 ]]; then
            export WINE_CPU_TOPOLOGY="${phys_count}:${phys_cpus}"
            launch_prefix+=(taskset -c "${phys_cpus}")
            log_info "CPU Pinning: ${phys_count} hilos ${cpu_slot} (${phys_cpus})."
        fi
    fi

    if [[ "${opt_gamemode}" == "1" ]] && command -v gamemoderun >/dev/null 2>&1; then
        launch_prefix+=(gamemoderun)
        log_info "GameMode activo (CPU performance + GPU high-perf)."
    fi

    if [[ "${opt_vkbasalt}" == "1" && -f "${L2_TOOLS_DIR}/vkbasalt/install/lib32/libvkbasalt.so" ]]; then
        export ENABLE_VKBASALT=1
        export VKBASALT_CONFIG_FILE="${L2_TOOLS_DIR}/vkbasalt/vkBasalt.conf"
        export VK_ADD_LAYER_PATH="${L2_TOOLS_DIR}/vkbasalt/layer.d${VK_ADD_LAYER_PATH:+:${VK_ADD_LAYER_PATH}}"
        export VK_INSTANCE_LAYERS="VK_LAYER_VKBASALT_post_processing${VK_INSTANCE_LAYERS:+:${VK_INSTANCE_LAYERS}}"
        log_info "vkBasalt 32-bit activo (SMAA + Tonemap + Vibrance + Curves + CAS, toggle: Home)."
    fi

    if [[ "${opt_mangohud}" == "1" ]]; then
        if [[ "${opt_dxvk}" == "1" && -d "${L2_TOOLS_DIR}/mangohud/layer.d" ]]; then
            export VK_ADD_LAYER_PATH="${L2_TOOLS_DIR}/mangohud/layer.d${VK_ADD_LAYER_PATH:+:${VK_ADD_LAYER_PATH}}"
            export MANGOHUD=1
            export MANGOHUD_CONFIG="${MANGOHUD_CONFIG:-position=top-right,fps,fps_metrics=0.01,frametime,frame_timing=1,cpu_stats,gpu_stats,font_size=18,background_alpha=0.45,toggle_hud=Shift_R+F12}"
            log_info "Telemetría MangoHud 32-bit activa (top-right, toggle: Shift_R+F12)."
        elif [[ "${opt_dxvk}" == "1" ]]; then
            export DXVK_HUD="${DXVK_HUD:-fps,frametimes,gpuload,scale=0.85,opacity=0.8}"
            log_info "Telemetría DXVK HUD activa (fps, frametimes, gpuload)."
        elif command -v mangohud >/dev/null 2>&1; then
            export MANGOHUD_CONFIG="${MANGOHUD_CONFIG:-position=top-right,fps,fps_metrics=0.01,frametime,frame_timing=1,cpu_stats,gpu_stats,font_size=18,background_alpha=0.45,toggle_hud=Shift_R+F12}"
            launch_prefix+=(mangohud --dlsym)
            log_info "Telemetría MangoHud activa (toggle: Shift_R+F12)."
        fi
    fi

    log_info "Iniciando Lineage 2 [${s_id}] con aceleración NVIDIA Turing..."
    cd "${client_system_dir}"
    "${launch_prefix[@]}" "${WINE}" "${l2_exe}"
}

cmd_download() {
    "${SCRIPT_DIR}/download_clients.sh" "$@"
}

usage() {
    echo "Uso: $0 {list|doctor|download <args>|setup <server_id>|run <server_id>}"
    echo ""
    echo "Comandos:"
    echo "  list               Lista los servidores y el estado de clientes y prefijos"
    echo "  doctor             Verifica hardware, controladores y dependencias de ejecución"
    echo "  download <args>    Gestiona la descarga y extracción de clientes (download_clients.sh)"
    echo "  setup <server_id>  Aprovisiona de forma desatendida el prefijo Wine y aplica el fine-tuning"
    echo "  run <server_id>    Lanza el juego con aceleración NVIDIA y DXVK"
    echo ""
}

case "${1:-}" in
    list)     cmd_list ;;
    doctor)   cmd_doctor ;;
    download) shift; cmd_download "$@" ;;
    setup)    shift; cmd_setup "$@" ;;
    run)      shift; cmd_run "$@" ;;
    *)        usage ;;
esac

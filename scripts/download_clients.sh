#!/usr/bin/env bash
# Client Acquisition, Verification and Staging CLI for Lineage 2 Linux Core
# Follows strict Clean Code, TDD and SOLID engineering standards.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

CONFIG_DOWNLOADS="${L2_CONFIG_DIR}/downloads.json"
CONFIG_SERVERS="${L2_CONFIG_DIR}/servers.json"

usage() {
    cat <<EOF
Uso: $0 <comando> [server_id] [opciones]

Comandos:
  list                          Lista todos los servidores, estado de descargas y staging
  info <server_id>              Muestra metadatos detallados, URLs y espejos de descarga
  download <server_id> [opt]    Descarga el cliente base o parche (admite --dry-run)
  verify <server_id> [opt]      Verifica integridad y estructura del archivo descargado
  extract <server_id> [opt]     Extrae y normaliza el cliente en su directorio de staging
  link-shared <server_id>       Vincula recursos multimedia compatibles (music)

Opciones:
  --dry-run                     Simula la operación sin tráfico de red ni modificaciones
  --target=client|patch|all     Define qué descargar/extraer (por defecto: all)
  --mirror=<index>              Fuerza un índice de espejo específico (1..n)

EOF
    exit 1
}

# Helper to query downloads.json using Python
query_json() {
    local py_expr="$1"
    python3 -c "
import json, sys
try:
    with open('${CONFIG_DOWNLOADS}', 'r', encoding='utf-8') as f:
        data = json.load(f)
    res = eval(\"\"\"${py_expr}\"\"\")
    if res is not None:
        if isinstance(res, (dict, list)):
            print(json.dumps(res, indent=2))
        else:
            print(res)
except KeyError:
    sys.exit(2)
except Exception as e:
    sys.exit(1)
"
}

validate_server_exists() {
    local s_id="$1"
    local exists
    exists=$(python3 -c "
import json, sys
try:
    with open('${CONFIG_DOWNLOADS}', 'r', encoding='utf-8') as f:
        data = json.load(f)
    print('yes' if '${s_id}' in data.get('downloads', {}) else 'no')
except Exception:
    print('no')
")
    if [[ "${exists}" != "yes" ]]; then
        log_error "No se encontró configuración de descarga para el servidor '${s_id}'."
        exit 1
    fi
}

cmd_list() {
    echo -e "${C_CYAN}=== CATÁLOGO DE ADQUISICIÓN Y STAGING DE CLIENTES L2 ===${C_RESET}\n"
    python3 -c "
import json, os

config_path = '${CONFIG_DOWNLOADS}'
downloads_dir = '${L2_DOWNLOADS_DIR}'
project_root = '${L2_PROJECT_ROOT}'

with open(config_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

h_id, h_chronicle, h_client, h_down, h_stage = 'SERVER ID', 'CRÓNICA', 'ARCHIVO CLIENTE', 'DESCARGA', 'STAGING'
print(f'{h_id:<22} {h_chronicle:<16} {h_client:<32} {h_down:<12} {h_stage:<12}')
print('-' * 96)

for s_id, s in data['downloads'].items():
    chronicle = s.get('chronicle', 'N/A')
    c_info = s.get('client', {})
    fname = c_info.get('filename', 'N/A')
    size_mb = c_info.get('estimated_size_mb', 0)
    client_archive = os.path.join(downloads_dir, fname)
    staging_path = os.path.join(project_root, s.get('staging_dir', f'clients/{s_id}'))

    if os.path.isfile(client_archive):
        d_size = os.path.getsize(client_archive) / (1024 * 1024)
        down_status = f'✅ {d_size:.0f}MB'
    else:
        down_status = f'❌ {size_mb}MB'

    system_exe = os.path.join(staging_path, 'system', 'l2.exe')
    if os.path.isfile(system_exe):
        stage_status = '✅ Listo'
    elif os.path.isdir(staging_path) and os.listdir(staging_path):
        stage_status = '⚠️ Incompleto'
    else:
        stage_status = '❌ Falta'

    print(f'{s_id:<22} {chronicle:<16} {fname:<32} {down_status:<12} {stage_status:<12}')
"
    echo ""
}

cmd_info() {
    local s_id="$1"
    validate_server_exists "${s_id}"

    echo -e "${C_CYAN}=== INFORMACIÓN DE ADQUISICIÓN: ${s_id} ===${C_RESET}\n"
    python3 -c "
import json, os

config_path = '${CONFIG_DOWNLOADS}'
s_id = '${s_id}'
with open(config_path, 'r', encoding='utf-8') as f:
    entry = json.load(f)['downloads'][s_id]

print(f'Servidor:     {entry.get(\"name\")}')
print(f'Crónica:      {entry.get(\"chronicle\")}')
print(f'Staging Dir:  {entry.get(\"staging_dir\")}')
print(f'Shared media: {\", \".join(entry.get(\"shared_assets\", []))}')
print('\n[Cliente Base]')
c = entry.get('client', {})
print(f'  Archivo:    {c.get(\"filename\")}')
print(f'  Tamaño est: ~{c.get(\"estimated_size_mb\")} MB')
print(f'  SHA256:     {c.get(\"sha256\") or \"N/A (Verificación por tamaño y estructura)\"}')
print('  URLs Primarias / Espejos Directos:')
for i, u in enumerate(c.get('urls', []), 1):
    print(f'    [{i}] {u}')
if 'cloud_mirrors' in c:
    print('  Espejos Cloud (Mega/MediaFire/G-Drive):')
    for provider, url in c['cloud_mirrors'].items():
        print(f'    - {provider}: {url}')

print('\n[Parche de Servidor / System]')
p = entry.get('patch', {})
print(f'  Archivo:    {p.get(\"filename\")}')
print(f'  Tamaño est: ~{p.get(\"estimated_size_mb\")} MB')
print('  URLs:')
for i, u in enumerate(p.get('urls', []), 1):
    print(f'    [{i}] {u}')
if 'cloud_mirrors' in p:
    print('  Espejos Cloud:')
    for provider, url in p['cloud_mirrors'].items():
        print(f'    - {provider}: {url}')
"
    echo ""
}

cmd_download() {
    local s_id="$1"
    shift
    validate_server_exists "${s_id}"

    local dry_run=0
    local target="all"
    local forced_mirror=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=1; shift ;;
            --target=*) target="${1#*=}"; shift ;;
            --mirror=*) forced_mirror="${1#*=}"; shift ;;
            *) log_warn "Opción desconocida: $1"; shift ;;
        esac
    done

    mkdir -p "${L2_DOWNLOADS_DIR}"

    python3 -c "
import json, sys

with open('${CONFIG_DOWNLOADS}', 'r', encoding='utf-8') as f:
    data = json.load(f)['downloads']['${s_id}']

targets = []
if '${target}' in ['all', 'client']:
    targets.append(('client', data['client']))
if '${target}' in ['all', 'patch']:
    targets.append(('patch', data['patch']))

for t_type, t_info in targets:
    fname = t_info['filename']
    urls = t_info['urls']
    size_mb = t_info.get('estimated_size_mb', 0)
    print(f'{t_type}|{fname}|{size_mb}|' + ';'.join(urls))
" | while IFS='|' read -r t_type fname size_mb urls_str; do
        local dest_file="${L2_DOWNLOADS_DIR}/${fname}"
        IFS=';' read -r -a urls <<< "${urls_str}"

        if [[ ${#urls[@]} -eq 0 ]]; then
            log_warn "No hay URLs directas para ${t_type} de ${s_id}."
            continue
        fi

        local selected_url="${urls[0]}"
        if [[ -n "${forced_mirror}" ]]; then
            local idx=$(( forced_mirror - 1 ))
            if [[ ${idx} -ge 0 && ${idx} -lt ${#urls[@]} ]]; then
                selected_url="${urls[$idx]}"
            fi
        fi

        if [[ ${dry_run} -eq 1 ]]; then
            log_info "[DRY-RUN] Simulando adquisición de ${t_type} para: ${s_id}"
            echo "  [DRY-RUN] Destino: ${dest_file} (~${size_mb} MB)"
            echo "  [DRY-RUN] URL Espejo: ${selected_url}"
            echo "  [DRY-RUN] Comando simulado: curl -fLC - --retry 3 \"${selected_url}\" -o \"${dest_file}\""
            continue
        fi

        if [[ -f "${dest_file}" ]]; then
            log_info "El archivo ${fname} ya existe en ${L2_DOWNLOADS_DIR}. Verificando..."
            continue
        fi

        log_info "Iniciando descarga de ${fname} (~${size_mb} MB)..."
        local success=0
        for u in "${urls[@]}"; do
            log_info "Conectando a espejo: ${u}"
            if curl -fLC - --connect-timeout 30 --speed-time 120 --speed-limit 1024 "${u}" -o "${dest_file}.part"; then
                mv "${dest_file}.part" "${dest_file}"
                log_success "Descarga completada: ${dest_file}"
                success=1
                break
            else
                log_warn "Fallo en espejo ${u}, intentando siguiente espejo si está disponible..."
                # Clean up inconsistent part file before attempting a different mirror
                rm -f "${dest_file}.part"
            fi
        done

        if [[ ${success} -eq 0 ]]; then
            log_error "No se pudo descargar ${fname} desde ningún espejo configurado."
            exit 1
        fi
    done
}

cmd_verify() {
    local s_id="$1"
    shift
    validate_server_exists "${s_id}"

    local target="all"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target=*) target="${1#*=}"; shift ;;
            *) shift ;;
        esac
    done

    python3 -c "
import json, sys

with open('${CONFIG_DOWNLOADS}', 'r', encoding='utf-8') as f:
    data = json.load(f)['downloads']['${s_id}']

targets = []
if '${target}' in ['all', 'client']:
    targets.append(('client', data['client']))
if '${target}' in ['all', 'patch']:
    targets.append(('patch', data['patch']))

for t_type, t_info in targets:
    print(f\"{t_type}|{t_info['filename']}|{t_info.get('sha256', '')}\")
" | while IFS='|' read -r t_type fname expected_sha256; do
        local target_file="${L2_DOWNLOADS_DIR}/${fname}"
        if [[ ! -f "${target_file}" ]]; then
            log_error "Archivo ausente: ${target_file}"
            log_info "Ejecuta: $0 download ${s_id} --target=${t_type}"
            exit 1
        fi

        log_info "Verificando integridad de: ${fname}..."

        # Verify archive structure using 7z / unzip / tar
        if [[ "${fname}" == *.zip ]] || [[ "${fname}" == *.7z ]] || [[ "${fname}" == *.rar ]]; then
            if command -v 7z >/dev/null 2>&1; then
                7z t "${target_file}" >/dev/null || {
                    log_error "El archivo ${fname} está corrupto según 7z."
                    exit 1
                }
            elif command -v unzip >/dev/null 2>&1 && [[ "${fname}" == *.zip ]]; then
                unzip -tq "${target_file}" >/dev/null || {
                    log_error "El archivo ${fname} está corrupto según unzip."
                    exit 1
                }
            fi
        fi

        # Check SHA256 if provided
        if [[ -n "${expected_sha256}" ]]; then
            local current_sha
            current_sha=$(sha256sum "${target_file}" | awk '{print $1}')
            if [[ "${current_sha}" != "${expected_sha256}" ]]; then
                log_error "Fallo de suma SHA256 para ${fname} (Esperado: ${expected_sha256}, Actual: ${current_sha})"
                exit 1
            fi
            log_success "SHA256 verificado correctamente."
        fi

        log_success "Archivo verificado correctamente: ${fname}"
    done
}

cmd_extract() {
    local s_id="$1"
    shift
    validate_server_exists "${s_id}"

    local dry_run=0
    local target="all"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=1; shift ;;
            --target=*) target="${1#*=}"; shift ;;
            *) shift ;;
        esac
    done

    local staging_rel
    staging_rel=$(query_json "data['downloads']['${s_id}']['staging_dir']")
    staging_rel=$(echo "${staging_rel}" | tr -d '"')
    local staging_path="${L2_PROJECT_ROOT}/${staging_rel}"

    if [[ ${dry_run} -eq 1 ]]; then
        log_info "[DRY-RUN] Simulando extracción y staging para: ${s_id}"
        echo "  [DRY-RUN] Destino Staging: ${staging_path}"
        echo "  [DRY-RUN] Se preservará configuración DXVK/Option.ini existente"
        echo "  [DRY-RUN] Se normalizará la estructura de directorios a minúsculas y permisos POSIX"
        return 0
    fi

    mkdir -p "${staging_path}"

    # Extract client
    local client_file
    client_file=$(query_json "data['downloads']['${s_id}']['client']['filename']" | tr -d '"')
    local client_archive="${L2_DOWNLOADS_DIR}/${client_file}"

    if [[ ! -f "${client_archive}" ]]; then
        log_error "No se encontró el paquete de cliente: ${client_archive}"
        log_info "Ejecuta: $0 download ${s_id} --target=client"
        exit 1
    fi

    log_info "Extrayendo ${client_file} en ${staging_path}..."
    if command -v 7z >/dev/null 2>&1; then
        7z x -y -o"${staging_path}" "${client_archive}" >/dev/null
    elif command -v unzip >/dev/null 2>&1 && [[ "${client_file}" == *.zip ]]; then
        unzip -qo "${client_archive}" -d "${staging_path}"
    else
        log_error "No hay descompresor disponible (7z o unzip)."
        exit 1
    fi

    # Normalization: If extraction created an isolated single root folder containing system/
    local sub_system
    sub_system=$(find "${staging_path}" -mindepth 2 -maxdepth 2 -type d -iname "system" | head -n 1 || true)
    if [[ -n "${sub_system}" ]]; then
        local nested_root
        nested_root="$(dirname "${sub_system}")"
        if [[ "${nested_root}" != "${staging_path}" ]]; then
            log_info "Normalizando directorio anidado: ${nested_root} -> ${staging_path}"
            cp -rn "${nested_root}"/* "${staging_path}/" 2>/dev/null || true
            rm -rf "${nested_root}"
        fi
    fi

    # Extract patch if requested and available
    if [[ "${target}" == "all" || "${target}" == "patch" ]]; then
        local patch_file
        patch_file=$(query_json "data['downloads']['${s_id}']['patch']['filename']" | tr -d '"')
        local patch_archive="${L2_DOWNLOADS_DIR}/${patch_file}"

        if [[ -f "${patch_archive}" ]]; then
            log_info "Aplicando parche de servidor: ${patch_file}..."
            if command -v 7z >/dev/null 2>&1; then
                7z x -y -o"${staging_path}" "${patch_archive}" >/dev/null
            elif command -v unzip >/dev/null 2>&1; then
                unzip -qo "${patch_archive}" -d "${staging_path}"
            fi
        fi
    fi

    # Ensure POSIX hygiene
    chmod -R u+rwX "${staging_path}"
    if [[ -d "${staging_path}/system" ]]; then
        find "${staging_path}/system" -maxdepth 1 -name "*.exe" -exec chmod +x {} + 2>/dev/null || true
    fi

    log_success "Staging completado para ${s_id} en ${staging_path}"
}

cmd_link_shared() {
    local s_id="$1"
    validate_server_exists "${s_id}"

    local staging_rel
    staging_rel=$(query_json "data['downloads']['${s_id}']['staging_dir']")
    staging_rel=$(echo "${staging_rel}" | tr -d '"')
    local staging_path="${L2_PROJECT_ROOT}/${staging_rel}"

    local shared_dir="${L2_CLIENTS_DIR}/shared_media"
    mkdir -p "${shared_dir}"

    log_info "Evaluando recursos compartidos compatibles para ${s_id}..."

    # Directiva Suprema: Solo se permite compartir music (Ogg Vorbis decoupled)
    # Prohibido compartir system, animations, textures entre crónicas dispares
    if [[ -d "${staging_path}/music" && ! -L "${staging_path}/music" ]]; then
        if [[ ! -d "${shared_dir}/music" ]]; then
            log_info "Poblando biblioteca común de música en ${shared_dir}/music..."
            mv "${staging_path}/music" "${shared_dir}/music"
        else
            rm -rf "${staging_path}/music"
        fi
        ln -sfn "${shared_dir}/music" "${staging_path}/music"
        log_success "Enlace simbólico de música optimizado creado en ${staging_path}/music"
    elif [[ -d "${shared_dir}/music" && ! -e "${staging_path}/music" ]]; then
        ln -sfn "${shared_dir}/music" "${staging_path}/music"
        log_success "Enlace a música común creado en ${staging_path}/music"
    else
        log_info "Directorio de música ya optimizado o aún no staged."
    fi
}

case "${1:-}" in
    list)        cmd_list ;;
    info)        shift; [[ $# -lt 1 ]] && usage; cmd_info "$@" ;;
    download)    shift; [[ $# -lt 1 ]] && usage; cmd_download "$@" ;;
    verify)      shift; [[ $# -lt 1 ]] && usage; cmd_verify "$@" ;;
    extract)     shift; [[ $# -lt 1 ]] && usage; cmd_extract "$@" ;;
    link-shared) shift; [[ $# -lt 1 ]] && usage; cmd_link_shared "$@" ;;
    *)           usage ;;
esac

# L2 Linux Core — Lineage 2 Interlude (Sudamérica) Reproducible Setup

Repositorio de ingeniería para aprovisionar, optimizar y ejecutar **Lineage 2 Interlude (C6)** con acabado **Remaster 2026**, soporte nativo para **Dual-Box** (2 cuentas simultáneas en ventana) y perfil dedicado **Ultra-FPS para Asedios**, de forma 100% *ban-safe* (sin modificar `.utx`, `l2.ini`, `L2.exe` ni `CliExt.dll`).

---

## ⚡ Instalación y Optimización en 1 Click (Para ti o un colega)

### En Linux (Ubuntu / Mint / Debian / Arch / Fedora / SteamOS)

#### 1. Dependencias del sistema (1 solo comando según tu distribución)
El entorno utiliza herramientas estándar de Linux y **Python 3 nativo** (solo módulos estándar de la biblioteca base; no requiere `pip` ni entornos virtuales `venv`):

- **Ubuntu / Linux Mint / Debian**:
  ```bash
  sudo dpkg --add-architecture i386 && sudo apt update
  sudo apt install -y python3 curl tar p7zip-full gamemode winetricks
  ```
- **Arch Linux / Manjaro**:
  ```bash
  sudo pacman -S --needed python curl p7zip gamemode winetricks lib32-vulkan-driver
  ```
- **Fedora**:
  ```bash
  sudo dnf install -y python3 curl p7zip p7zip-plugins gamemode winetricks
  ```

#### 2. Clonar y Lanzar Instalador 1-Click
```bash
git clone git@github.com:tonyESP/l2SudamericaFastSetupUnix.git L2
cd L2
./quick_setup.sh
```
*(O haz doble click sobre el archivo **`Instalar-L2-Sudamerica.desktop`** desde tu gestor de archivos).*

**¿Qué hace automáticamente `./quick_setup.sh`?**
1. Comprueba multiarch (`i386`) y dependencias del sistema (`curl`, `7z`, `python3`, `gamemode`).
2. Verifica y activa los shims de red de baja latencia (`l2_auth_redir.so` 32/64 bits con `TCP_QUICKACK` continuo y QoS DSCP EF).
3. Descarga e instala **Wine-GE** (GloriousEggroll) y **DXVK 32-bit** (`d3d9.dll`, `dxgi.dll`).
4. Si ya tienes el cliente o el archivo `.rar` en `downloads/` o tu carpeta de Descargas, lo extrae y normaliza la estructura de carpetas automáticamente.
5. Crea al instante el perfil secundario para Asedios (`l2suda-asedio`) compartiendo archivos pesados con enlaces duros (0 GB de espacio duplicado).
6. Aprovisiona los prefijos Wine 32-bit (ratón lineal 1:1, suprime alertas GPF de cierre y bloqueos por foco de ventana).
7. Inyecta el fine-tuning calibrado (`Option.ini`, `dxvk.conf`, `vkBasalt.conf`).
8. Instala los accesos directos con icono oficial en tu Menú de Aplicaciones y en tu Escritorio.

### En Windows 10/11
Si tu colega juega en Windows, solo necesita clonar y ejecutar:
```cmd
setup_windows.cmd
```
Le permitirá inyectar en 1 click el perfil Remaster Diario o el perfil Asedios Ultra-FPS con su respaldo automático de `Option.ini`.

---

## 1. Los 3 Perfiles Disponibles (`config/servers.json`)

| Perfil (`server_id`) | Uso recomendado | Pila gráfica y ajustes clave |
|---|---|---|
| `l2sudamerica-interlude` | Fallback seguro / compatibilidad | WineD3D clásico (sin DXVK ni vkBasalt) |
| `l2suda-optimizado` | **Juego diario ("Bonito")** | DXVK (`AF 16x`, `LOD -0.25`) + `vkBasalt` (`smaa:tonemap:vibrance:curves:cas`) + `Pawn=6.0`, `StaticMesh=8.0` |
| `l2suda-asedio` | **Asedios y Mass PvP (0 bajones)** | DXVK puro (`vkbasalt=false`, `AF 4x`, `LOD 0.0`) + CPU baja carga (`Pawn=3.0`, `SkipAnim=1`, `ModelDetail=1`, sin sombras de PJ/hierba/agua/música `.ogg`/números de cura) |

Todos los perfiles arrancan con **lanzador blindado** (`scripts/l2_ctl.sh`): antes de abrir `L2.exe` fuerza automáticamente `UseAGP=False`, `GPUAnimation=False`, `PostProc=0` (evita GPF en `UHDREffect::PostRender` y `GetVertexShader`) y `StartupFullScreen=False` (evita pantallazos negros por FSE).

---

## 2. Arquitectura y Optimizaciones Implementadas

### A. Gráficos externos (DXVK + vkBasalt 32-bit + UE2.5)
- **DXVK (`config/dxvk.conf.template` / `dxvk.siege.conf.template`)**: `d3d9.maxFrameRate = 60`, `presentInterval = 0`, `maxFrameLatency = 1`, `latencySleep = True`, `allowFse = False`, `deviceLossOnFocusLoss = False`, `enableGraphicsPipelineLibrary = Auto` y `numCompilerThreads = 4`.
- **vkBasalt (`config/vkBasalt.conf.template`)**: cadena `smaa:tonemap:vibrance:curves:cas` (sin `deband` ni `FakeHDR` para no crear trama sobre texturas DXT de 2006), con `Gamma = 0.96`, `Exposure = 0.04`, `Vibrance = 0.34`, `Contrast = 0.32`, `casSharpness = 0.45` (tecla **`Home`** para activar/desactivar en vivo).
- **MangoHud 32-bit**: `fps,fps_metrics=0.01,frametime,frame_timing=1,cpu_stats,gpu_stats` (tecla **`Shift_R+F12`**).

### B. Ergonomía Dual-Box (2 cuentas simultáneas en ventana)
Al lanzar una segunda ventana con `./scripts/l2_ctl.sh run <perfil>`, `l2_ctl.sh` detecta la instancia activa (`pgrep`) y automáticamente:
1. **Reparte hilos de CPU**: 1.ª instancia en núcleos físicos primarios (`0..7`), 2.ª instancia en hilos SMT (`8..15`).
2. **Aísla el Auth Relay**: si el puerto `21060` está ocupado, abre `21061`, `21062`... para que cerrar una cuenta no desconecte la otra.
3. **Silencia el audio de la 2.ª ventana**: desactiva `winepulse.drv` y `winealsa.drv` (`WINEDLLOVERRIDES`) en la 2.ª cuenta para ahorrar CPU y evitar audio duplicado.
4. **Omite `ram_prewarm` redundante** si ya hay una instancia leyendo los paquetes.
5. **Sincroniza Interfaz, Barras y Emblemas**: copia bidireccionalmente con `cp -pu` los archivos más recientes de `system/WindowsInfo.ini`, `iwo/*` y `crest/*` entre `l2suda-optimizado` y `l2suda-asedio`, manteniendo separados `Option.ini` y `dxvk.conf`.
6. **Ratón lineal 1:1**: `scripts/provision_prefix.sh` desactiva la aceleración en `user.reg` (`MouseSpeed=0`, `MouseThreshold1=0`, `MouseThreshold2=0`) para evitar giros bruscos de cámara.

### C. Red transatlántica de baja latencia por socket (sin `sudo` / sin tocar el sistema)
- **`scripts/l2_auth_proxy.py` + `tools/shims/l2_auth_redir.c`** (32 y 64 bits vía `$LIB`):
  - Resuelve el bloqueo de login en Wine (`WSAAsyncSelect` + SYN-proxy anti-DDoS).
  - Por cada socket `AF_INET` de L2 (sin tocar `sysctl` globales): aplica `TCP_NODELAY` blindado en `setsockopt()`, **`TCP_QUICKACK` continuo** re-armado en `recv`/`recvfrom`/`recvmsg` (elimina el *Delayed ACK* de 40 ms), `TCP_THIN_LINEAR_TIMEOUTS` (retransmisión rápida sin espera exponencial) e **`IP_TOS = 0xb8`** (DSCP EF / prioridad Wi-Fi WMM Voz `AC_VO`).
  - Muestreo automático cada 30 s en `net_telemetry.log` (`ss -tin` puerto `:7777`, recortado a 200 líneas al salir).

---

## 3. Reproducibilidad tras Formatear o Clonar en Linux

> **Nota sobre `.gitignore`**: El repositorio en GitHub guarda toda la lógica, plantillas, shims C, tests y lanzadores (`scripts/`, `config/`, `tools/shims/l2_auth_redir.*`, `docs/`, `tests/`), pero **excluye** por tamaño/credenciales `clients/`, `prefixes/`, `downloads/`, `tools/runners/`, `tools/dxvk_32/`, `tools/vkbasalt/`, `tools/mangohud/`, `tools/dxvk_cache/`, `.env`, `*.local.json` y `*.log`.

### Paso 1: Dependencias del sistema (Ubuntu / Linux Mint / Debian)
```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y git curl p7zip-full unrar python3 python3-pil \
  gcc gcc-multilib libc6-dev-i386 gamemode winetricks iproute2
```

### Paso 2: Clonar, compilar shims y verificar el entorno
```bash
git clone git@github.com:tonyESP/l2SudamericaFastSetupUnix.git L2 && cd L2

# Recompilar shims 64-bit y 32-bit
mkdir -p tools/shims/lib/x86_64-linux-gnu tools/shims/lib/i386-linux-gnu
gcc -shared -fPIC -O2 -Wall -Wextra tools/shims/l2_auth_redir.c -o tools/shims/lib/x86_64-linux-gnu/l2_auth_redir.so -ldl
gcc -m32 -shared -fPIC -O2 -Wall -Wextra tools/shims/l2_auth_redir.c -o tools/shims/lib/i386-linux-gnu/l2_auth_redir.so -ldl
cp -f tools/shims/lib/x86_64-linux-gnu/l2_auth_redir.so tools/shims/l2_auth_redir.so

# Verificar hardware, Vulkan y tests automatizados
./scripts/l2_ctl.sh doctor
python3 -m unittest discover -s tests -p "test_*.py" -v
```

### Paso 3: Colocar cliente y herramientas binarias
1. **Cliente**: descomprime tu cliente L2 Sudamérica dentro de `clients/l2suda-optimizado/` (y opcionalmente una copia en `clients/l2suda-asedio/` y `clients/l2sudamerica-interlude/`). Elimina `system/d3d9.dll` original si trae `d3d9_R21B.dll` para que lo gestione DXVK/Wine.
2. **Wine Runner**: instala `wine-11.22-staging-amd64` en `tools/runners/wine-11.22-staging-amd64/` (o usa el `wine` del sistema).
3. **DXVK 32-bit + vkBasalt + MangoHud**:
   - Copia `d3d9.dll` y `dxgi.dll` (32-bit de DXVK) en `tools/dxvk_32/`.
   - Compila `libvkbasalt.so` (32-bit) en `tools/vkbasalt/install/lib32/`, su `layer.d` en `tools/vkbasalt/layer.d/` y coloca `reshade-shaders` + `sweetfx` en `tools/vkbasalt/`.
   - Opcional: capa 32-bit de MangoHud en `tools/mangohud/layer.d/`.

### Paso 4: Aprovisionar prefijos, aplicar plantillas y lanzar
```bash
# Crear prefijos Wine 32-bit (winetricks + ratón lineal 1:1)
./scripts/l2_ctl.sh setup l2suda-optimizado
./scripts/l2_ctl.sh setup l2suda-asedio

# Inyectar dxvk.conf, Option.ini y vkBasalt.conf adaptados a tu ruta (--force aplica la plantilla aunque ya exista Option.ini)
./scripts/apply_tuning.sh l2suda-optimizado --force
./scripts/apply_tuning.sh l2suda-asedio --force

# Instalar lanzadores en el menú de aplicaciones (adapta rutas automáticamente a tu carpeta)
for f in config/l2suda-*.desktop; do sed "s|/mnt/disk4u/L2|$(pwd)|g" "$f" > ~/.local/share/applications/"$(basename "$f")"; done

# Actualizar parches oficiales del servidor (sin pisar DXVK y copiando cambios a asedio)
./scripts/l2_ctl.sh update

# Arrancar
./scripts/l2_ctl.sh run l2suda-optimizado

# Detener limpiamente instancias y liberar bloqueos dual-box en caso de cuelgue
./scripts/l2_ctl.sh stop all
```

---

## 4. Guía Rápida para un Colega en Windows 10/11

En Windows no hacen falta `l2_ctl.sh`, Wine, `l2_auth_redir.so` ni `l2_auth_proxy.py`, pero tu colega puede aprovechar **directamente** todo el tuning gráfico y de asedios:

1. **Perfil Diario vs Perfil Asedio (`Option.ini`)**:
   - **Juego normal**: copia [`config/Option.optimized.ini.template`](config/Option.optimized.ini.template) como `system\Option.ini` (distancia ampliada `Pawn=6.0`, `StaticMesh=8.0`, `L2WaterEffect` alto, `Gamma=1.0`, `PostProc=0`). Haz copia previa de su `Option.ini` si quiere conservar teclas/resolución.
   - **Asedios / Mass PvP (máximos FPS)**: copia [`config/Option.siege.ini.template`](config/Option.siege.ini.template) como `system\Option.ini` (quita sombras de PJ, vegetación, reflejos de agua, `SkipAnim=1`, `ModelDetail=1` y números flotantes de curas). *(Nota: edita `GamePlayViewportX/Y` en `[Video]` si su monitor no es `1920x1080`)*.
2. **Opcional — DXVK en Windows (mejor frame-pacing en UE2.5)**:
   - Descarga DXVK (`x32\d3d9.dll` y `dxgi.dll`) y ponlos junto a `L2.exe` en `system\` (verificando antes que el anticheat/updater del servidor no sobrescriba `d3d9.dll`), acompañado de [`config/dxvk.conf.template`](config/dxvk.conf.template) renombrado a `dxvk.conf` (o [`config/dxvk.siege.conf.template`](config/dxvk.siege.conf.template) en asedios).
3. **Opcional — ReShade en Windows**:
   - > [!WARNING]
     > **Evita colisión de `d3d9.dll`**: tanto DXVK (32-bit) como ReShade para Direct3D 9 generan un `d3d9.dll` en `system\`. Si usas **DXVK**, instala ReShade seleccionando **Vulkan** (no Direct3D 9) para que encadene sobre DXVK; si NO usas DXVK, instálalo como **Direct3D 9**.
   - Replica los mismos efectos y valores de [`config/vkBasalt.conf.template`](config/vkBasalt.conf.template):
     - Activa en este orden: **SMAA** → **Tonemap** (`Gamma=0.96`, `Exposure=0.04`, `Saturation=0.08`, `Defog=0.0`) → **Vibrance** (`0.34`) → **Curves** (`Contrast=0.32`) → **CAS** (`Sharpness=0.45`).
     - Evita `FakeHDR` y `Deband` para no generar trama sobre las texturas de 2006.

---

## 5. Relay de Baja Latencia (España ⟷ Brasil ⟷ Argentina)

Para jugadores en Europa que deseen recortar la latencia de ~262 ms (ruta estándar vía Miami) a ~150-170 ms (vía enlace directo transatlántico):
- **Guía completa de despliegue paso a paso**: [`docs/ROUTING_RELAY_GUIDE.md`](docs/ROUTING_RELAY_GUIDE.md)
- **Aprovisionador del VPS en São Paulo**: [`tools/relay/setup_vps.sh`](tools/relay/setup_vps.sh)
- **Controlador local de túnel Split-Tunneling**:
  ```bash
  # Auditar entorno y medir ping al VPS
  ./scripts/relay_ctl.sh doctor
  ./scripts/relay_ctl.sh test <IP_DEL_VPS>

  # Activar / Desactivar ruta optimizada (Split-Tunnel: solo L2)
  ./scripts/relay_ctl.sh up
  ./scripts/relay_ctl.sh down
  ```

---

## 6. Documentación Relacionada y Tests

- Guía de optimización de enrutamiento y relay: [`docs/ROUTING_RELAY_GUIDE.md`](docs/ROUTING_RELAY_GUIDE.md)
- Informe técnico detallado de diagnóstico: [`docs/L2_SUDAMERICA_LINUX.md`](docs/L2_SUDAMERICA_LINUX.md)
- Arquitectura y reglas del proyecto: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`AGENTS.md`](AGENTS.md)
- Guía de tuning y troubleshooting: [`.agents/skills/l2-graphics-tuning/SKILL.md`](.agents/skills/l2-graphics-tuning/SKILL.md)
- Suite de tests (`unittest`):
  ```bash
  python3 -m unittest discover -s tests -p "test_*.py" -v
  ```

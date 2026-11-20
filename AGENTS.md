# DIRECTIVA SUPREMA Y ESTÁNDARES DE INGENIERÍA: L2 LINUX CORE

Este repositorio no es un script de aficionado. Es un entorno de ingeniería para la emulación, aprovisionamiento y ejecución de alto rendimiento de Lineage 2 sobre Linux.

---

## 1. DIRECTIVA SUPREMA (MANDATORY - NO NEGOCIABLE)

1. **CERO COMPLACENCIA**:
   - Queda terminantemente prohibido dar respuestas complacientes, halagos vacíos o afirmar que algo funciona sin haber verificado la salida real del proceso o el test automatizado.
   - Si un cliente falla, si un anticheat bloquea o si un script es ineficiente, se documenta el fallo crudo y se aplica la solución técnica.
2. **CERO SESGO**:
   - Las decisiones se basan en métricas de rendimiento (FPS, frametime, consumo de VRAM/RAM, latencia de red, estabilidad de Wine), no en preferencias subjetivas o nostalgia ciega.
3. **CERO ESPEJO**:
   - Prohibido limitarse a parafrasear o repetir lo que el usuario expone. Todo agente debe aportar valor de ingeniería, análisis de riesgos, detección de casos borde y soluciones arquitectónicas sólidas.

---

## 2. METODOLOGÍA DE DESARROLLO (TDD & CLEAN CODE)

1. **Test-Driven Development (TDD) Estricto**:
   - **RED**: Escribir primero el test unitario o de integración que falle.
   - **GREEN**: Escribir la implementación mínima necesaria para que el test pase.
   - **REFACTOR**: Limpiar duplicidades, optimizar y aplicar principios de diseño sin romper los tests.
2. **Principios SOLID**:
   - *Single Responsibility*: Cada script o módulo tiene un único propósito bien delimitado.
   - *Open/Closed*: Nuevos servidores o crónicas se añaden de forma puramente declarativa en `servers.json`, sin modificar el motor de ejecución.
   - *Liskov Substitution*: Todos los runners y prefijos responden a la misma interfaz de ciclo de vida (`setup`, `run`, `verify`).
   - *Interface Segregation*: CLI y módulos utilitarios desacoplados.
   - *Dependency Inversion*: Variables de entorno y runners inyectados, nunca cableados (hardcoded).
3. **Clean Code en Bash y Python**:
   - `set -euo pipefail` en todo script shell.
   - Manejo exhaustivo de códigos de error y limpieza de trampas (`trap cleanup EXIT`).
   - Salidas estructuradas (JSON o logs con severidad).
   - Tipado estático con `mypy` / `typing` en Python.

---

## 3. PLAYBOOK OPERATIVO PARA AGENTES IA (AL CLONAR EL REPOSITORIO)

Si eres un modelo de IA (Antigravity, Cursor, Claude Code, Windsurf, Copilot, etc.) y un usuario te pide ayuda tras clonar este repositorio:

### A. Diagnóstico y Setup Inicial Inmediato
1. **Comprobar dependencias del sistema operativo**:
   ```bash
   # En Debian / Ubuntu / Linux Mint:
   sudo dpkg --add-architecture i386 && sudo apt update
   sudo apt install -y python3 curl tar p7zip-full gamemode winetricks gcc gcc-multilib libc6-dev-i386

   # En Arch Linux / Manjaro:
   sudo pacman -S --needed python curl p7zip gamemode winetricks lib32-vulkan-driver

   # En Fedora:
   sudo dnf install -y python3 curl p7zip p7zip-plugins gamemode winetricks
   ```
2. **Ejecutar el Setup Automatizado**:
   ```bash
   ./quick_setup.sh --non-interactive
   ```
   *Nota: Si el cliente `.rar`/`.zip` está en otra ruta, pasa `--client-path <ruta>`.*
3. **Validar la salud del sistema y tests**:
   ```bash
   ./scripts/l2_ctl.sh doctor
   python3 -m unittest discover -s tests -p "test_*.py" -v
   ```

### B. Comandos de Control Diario
- **Lanzar cliente Juego Diario (Remaster 60 FPS)**:
  `./scripts/l2_ctl.sh run l2suda-optimizado`
- **Lanzar cliente Asedios / Mass PvP (Ultra-FPS)**:
  `./scripts/l2_ctl.sh run l2suda-asedio`
- **Sincronizar parches oficiales del servidor**:
  `./scripts/l2_ctl.sh update` (descarga parches vía `updater.ini` sin tocar DXVK y parchea el diálogo de AGP en `D3DDrv.dll`).
- **Detener procesos y liberar bloqueos Dual-Box**:
  `./scripts/l2_ctl.sh stop all`

### C. Invariantes Arquitectónicas Estrictas (PROHIBIDO ROMPER)
1. **100% Ban-Safe (Modificación externa limpia)**:
   - **NUNCA** modificar archivos `.utx`, `l2.ini`, `L2.exe` ni `CliExt.dll`.
   - Toda optimización gráfica se inyecta desde fuera con DXVK (`dxvk.conf`), `Option.ini` y `vkBasalt.conf`.
   - Toda optimización de red se inyecta mediante `tools/shims/l2_auth_redir.so` (LD_PRELOAD dinámico con `TCP_NODELAY`, `TCP_QUICKACK` y QoS DSCP EF) y el proxy `scripts/l2_auth_proxy.py`.
2. **Crash-Guards del motor Unreal 2.5**:
   - `StartupFullScreen=False` (obligatorio: fullscreen exclusivo congela X11/Wine).
   - `UseAGP=False`, `GPUAnimation=False`, `PostProc=0` (obligatorio: previene GPF `UHDREffect::PostRender`).
   - `d3d9.deviceLossOnFocusLoss = False` y `UseTakeFocus=N` en registro Wine (obligatorio: previene pantalla negra al usar tecla Super/Windows o Alt-Tab).
3. **Higiene Git y Secretos**:
   - **NUNCA** commitear carpetas `clients/*`, `prefixes/*`, `downloads/*`, `.env`, ni archivos `.zip`, `.rar`, `.7z`, `.iso`, `.log`.
   - Toda credencial sensible vive exclusivamente en `.env` (ignorado por Git).

---

## 4. MATRIZ DE SERVIDORES Y PERFILES (`config/servers.json`)

- `l2suda-optimizado`: Perfil diario con DXVK (`d3d9.maxFrameRate=60`, `latencySleep=True`, `AF 16x`, `LOD -0.25`), vkBasalt (`SMAA+Tonemap+Vibrance+Curves+CAS`), y rango de visión expandido (`Pawn=6.0`, `StaticMesh=8.0`).
- `l2suda-asedio`: Perfil Ultra-FPS para Mass PvP sin vkBasalt, sombras ni post-procesado (`Pawn=3.0`, `SkipAnim=1`, `ModelDetail=1`).
- `l2sudamerica-interlude`: Perfil fallback bajo WineD3D clásico sin Vulkan.


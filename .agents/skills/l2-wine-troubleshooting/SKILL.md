---
name: l2-wine-troubleshooting
description: Diagnóstico y resolución de fallos de red (WSAAsyncSelect), renderizado (D3DDrv/d3d9), case-sensitivity y updaters de Lineage 2 bajo Wine en Linux.
---

# L2 Wine Troubleshooting & Engineering Runbook

Skill de referencia para diagnosticar y resolver bloqueos reales de clientes privados de Lineage 2 (Interlude / C6+) bajo Linux/Wine.

## 1. Login congelado o desconexión inmediata (`WSAAsyncSelect` + Anti-DDoS RTT)

### Síntoma
- Al pulsar **Log In**, el cliente no hace nada o muestra *"You have been disconnected from the server. Please login again."*
- Una conexión TCP directa desde Python (`45.235.99.29:2106`) sí recibe el paquete `Init` (186 bytes), pero `L2.exe` bajo Wine realiza **0 llamadas `recv()`**.

### Causa raíz
- `L2.exe` registra `WSAAsyncSelect(..., 0x507, FD_CONNECT)`, lanza `connect()` (`EINPROGRESS`) y **~48 ms después** llama a `WSAAsyncSelect(..., 0x508, FD_READ | FD_OOB | FD_CLOSE)`.
- Si el AuthServer remoto tarda >50 ms en completar el `SYN-ACK` (p. ej. ~1280 ms por mitigación anti-DDoS), Wine pierde la transición de `FD_CONNECT`/`FD_READ` y nunca invoca `recv()`.
- **Nota crítica**: Bloquear `connect()` con `poll()` y devolver `0` síncrono **rompe** la máquina de estados `WSAAsyncSelect` de Wine; Wine necesita recibir `EINPROGRESS` contra un socket local rápido.

### Solución integrada
1. Declarar en `config/servers.json`:
   ```json
   "auth_proxy": {
     "host": "l2.lineage2sudamerica.com",
     "port": 2106
   }
   ```
2. `scripts/l2_ctl.sh` arranca automáticamente `scripts/l2_auth_proxy.py` en `127.0.0.1:21060` e inyecta `LD_PRELOAD=tools/shims/l2_auth_redir.so`.
3. `connect()` hacia el puerto `2106` se redirige a `127.0.0.1:21060` (`EINPROGRESS` < 1 ms) y el proxy retransmite de forma transparente al servidor real.

## 2. Modal bloqueante *"AGP is deactivated"* en `D3DDrv.dll`

### Síntoma
- `UseAGP=False` en `system/Option.ini` no suprime el popup modal de DirectDraw AGP.

### Causa raíz y solución
- `D3DDrv.dll` comprueba capacidades hardware DirectDraw (`test DWORD PTR [ebx+0x41c4], 0x1000`) antes de consultar `Option.ini`.
- Aplicar el binario parcheado `tools/patches/D3DDrv.dll.noagp` (conservando `D3DDrv.dll.orig`), que salta la comprobación (`1001c437`: `eb 6f`) y anula `MessageBoxW` (`1001c4a2`: `31 c0 90 90 90 90`).

## 3. Proxies `system/d3d9.dll` y elección WineD3D vs DXVK

- Algunos clientes privados incluyen un `system/d3d9.dll` wrapper (p. ej. `d3d9_R21B.dll`) que provoca fallos de inicialización bajo Wine/DXVK (`dxvk::DxvkError`).
- Eliminar `system/d3d9.dll` conflictivo. Si DXVK sigue fallando con el binario del servidor, usar WineD3D (`WINEDLLOVERRIDES="dsetup=n,b"` sin override de `d3d9`) y runner `wine-11.22-staging-amd64` declarado en `config/servers.json` (`"runner": "wine-11.22-staging-amd64"`).

## 4. Updaters, Interfaces base (2.0 / 3.0) y Case-Sensitivity en `ext4`

- **Base completa antes del updater**: Muchos servidores distribuyen un cliente base con la interfaz (`Interface.u`, `interface.xdat`, `InterfaceTextures*.u`) que **no** está en `updater.ini`. Extraer primero el cliente base (p. ej. `l2Sudamerica_fafureon_30.rar` con `unrar` si `7z` da `Unsupported Method` en RAR5) y después sincronizar `updater.ini`.
- **Case-sensitivity en Linux**: Al aplicar `updater.ini` sobre un cliente ya extraído en `ext4`, resolver rutas de forma **case-insensitive** (`Engine.dll` vs `engine.dll`, `Npcgrp.dat` vs `npcgrp.dat`) para sobrescribir los archivos reales sin crear duplicados.
- **Symlink `l2.exe -> L2.exe`**: Mantener `L2.exe` como binario principal y `l2.exe` como enlace simbólico si el updater y `servers.json` difieren en mayúsculas.

## 5. General Protection Fault en `UD3DRenderDevice::GetVertexShader` / `USubSkeletalMeshInstance::Render`

### Síntoma
- Crash al renderizar personajes o NPCs con:
  `General protection fault! History: UD3DRenderDevice::GetVertexShader <- FD3DRenderInterface::SetVertexStreams <- USubSkeletalMeshInstance::Render`

### Causa raíz y solución
- Bajo **WineD3D**, activar `GPUAnimation=True` y/o `PostProc=3` en `system/Option.ini` provoca fallos al compilar/enlazar vertex shaders de skeletal meshes.
- Mantener en `system/Option.ini`:
  - `GPUAnimation=False`
  - `PostProc=0`
  - `AntiAliasing=0`

## 6. `Assertion failed: InPos<=Size` en `RidePacket` (`SkeletalMesh ... NULL`)

### Síntoma
- Crash en mundo abierto al aparecer otro jugador en montura custom:
  `Assertion failed: InPos<=Size [File:..\..\Core\Inc\FFileManagerWindows.h] [Line: 185] ... (Engine.SkeletalMesh LineageNpcs_LionManed_byNevesOma.NevesOma_ManedWyvern_m00 NULL) <- Function Name=RidePacket`

### Causa raíz y solución
- Un cliente vanilla (`Interlude.7z`) + `updater.ini` **no** incluye paquetes custom de monturas/NPCs que solo vienen dentro del cliente completo del servidor (p. ej. `l2Sudamerica_fafureon_30.rar`).
- Extraer siempre primero el archivo completo de Interface del servidor antes de ejecutar `updater_sync.py`.

## 7. Pantalla negra permanente al minimizar/desminimizar en Linux (`d3d9.deviceLossOnFocusLoss`)

### Síntoma
- El cliente está corriendo en modo ventana o sin bordes bajo Wine + DXVK.
- Al pulsar el botón de minimizar a la barra de tareas y luego hacer clic en la ventana para restaurarla, la ventana queda completamente en negro.
- En la telemetría de red, el socket TCP sigue vivo y recibiendo paquetes del GameServer (`data_segs_in` crece), pero `data_segs_out` queda completamente congelado (deadlock del bucle de presentación).

### Causa raíz
- En Linux (X11 / compositores como Cinnamon/Muffin o KWin), minimizar la ventana desmapea la superficie gráfica (`UnmapNotify`, 0x0 píxeles).
- En Vulkan, el swapchain pasa a estado `VK_ERROR_OUT_OF_DATE_KHR`.
- Si DXVK tiene `d3d9.deviceLossOnFocusLoss = False`, le oculta a Direct3D 9 la pérdida de dispositivo. El motor de L2 (`D3DDrv.dll`) asume que la superficie sigue intacta y **nunca invoca `IDirect3DDevice9::Reset()`**.
- Al desminimizar, DXVK no tiene orden de recrear el swapchain y el motor intenta pintar en un búfer nulo, resultando en una pantalla negra perpetua.

### Solución integrada
1. Establecer obligatoriamente en `dxvk.conf` y plantillas:
   ```ini
   d3d9.deviceLossOnFocusLoss = True
   ```
2. Al perder foco/minimizar, DXVK notifica `D3DERR_DEVICELOST`. Al restaurar, devuelve `D3DERR_DEVICENOTRESET`, obligando a `D3DDrv.dll` a llamar a `Reset()` y reconstruir el swapchain de Vulkan de inmediato.
3. Si `vkBasalt` pierde sincronía de shaders al redimensionar, la tecla `Home` / `Inicio` permite alternar el postprocesado en caliente para forzar el repintado del frame nativo.

## 8. Gestión de cuelgues y limpieza de recursos dual-box (`stop` / `kill`)

Para terminar de forma segura instancias colgadas sin dejar sockets huérfanos ni locks de dual-box:
```bash
# Detener todas las instancias de L2 y procesos asociados limpiamente
./scripts/l2_ctl.sh stop all

# O detener un perfil específico
./scripts/l2_ctl.sh stop l2suda-optimizado
```
El comando purga los PIDs en `/tmp/l2_dualbox_${UID}/slot_*.pid`, libera `launch.lock` y mata los procesos huérfanos con SIGTERM y SIGKILL si no responden.

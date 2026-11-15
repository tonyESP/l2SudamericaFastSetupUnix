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

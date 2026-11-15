# L2 Sudamérica (Interlude) en Linux — Informe de Ingeniería

Este documento registra el diagnóstico completo, los parches aplicados y la arquitectura final que permite ejecutar **L2 Sudamérica (Interlude x10)** de forma estable bajo Linux/Wine desde [`scripts/l2_ctl.sh`](../scripts/l2_ctl.sh).

## 1. Cadena de montaje del cliente (`clients/l2sudamerica-interlude`)

1. **Cliente base estable (`Interlude.7z`)**:
   - Extraída la base limpia `downloads/Interlude.7z` (sin los paquetes pesados de Interface 3.0, que provocaban congelamiento al entrar en cuevas bajo WineD3D).
2. **Sincronización oficial `updater.ini`**:
   - Descargados y verificados por MD5 los 119 archivos de `http://l2updates.com/sudamerica/updater/` usando resolución case-insensitive en `ext4` para sobrescribir correctamente `engine.dll`, `npcgrp.dat`, `lineagemonsterstex.utx`, `lineagemonsterstex2.utx`, `l2.ini`, `L2.exe` y el contenido custom (`animations/*SudAmerica*.ukx`, `system/L2S*.u`, `maps/`, etc.).
3. **Limpieza y parche gráfico (`D3DDrv.dll.noagp`)**:
   - Eliminado `system/d3d9.dll` (`d3d9_R21B.dll`) por incompatibilidad con Wine/DXVK.
   - Aplicado [`tools/patches/D3DDrv.dll.noagp`](../tools/patches/D3DDrv.dll.noagp) sobre `system/D3DDrv.dll` (respaldo en `D3DDrv.dll.orig`) para suprimir el modal bloqueante de AGP desactivado (`test DWORD PTR [ebx+0x41c4], 0x1000` + `MessageBoxW`).
   - Inyectado `UseAGP=False` en `system/Option.ini` y `system/dxvk.conf` mediante `scripts/apply_tuning.sh`.

## 2. Solución al bloqueo de Login (`WSAAsyncSelect` + Anti-DDoS)

### Diagnóstico
Mediante `WINEDEBUG=+winsock` y trazado `LD_PRELOAD` se comprobó que:
- El AuthServer `l2.lineage2sudamerica.com` (`45.235.99.29:2106`) tarda ~1.28 s en devolver el TCP `SYN-ACK`.
- `L2.exe` registra `WSAAsyncSelect(0x507, FD_CONNECT)`, ejecuta `connect()` (`EINPROGRESS`) y **48 ms después** sobrescribe el evento con `WSAAsyncSelect(0x508, FD_READ|FD_OOB|FD_CLOSE)`.
- Al completarse el `SYN-ACK` 1.2 s más tarde, Wine no entrega `FD_READ` y `L2.exe` nunca ejecuta `recv()`.

### Implementación
- **Shim C (`LD_PRELOAD`)**: [`tools/shims/l2_auth_redir.c`](../tools/shims/l2_auth_redir.c) -> `tools/shims/l2_auth_redir.so`. Intercepta `connect()` al puerto `L2_AUTH_TARGET_PORT` (2106) y lo redirige a `127.0.0.1:L2_AUTH_PROXY_PORT` (21060) preservando el flujo asíncrono `EINPROGRESS` (<1 ms).
- **Relay TCP en Python**: [`scripts/l2_auth_proxy.py`](../scripts/l2_auth_proxy.py). Acepta conexiones locales y retransmite de forma transparente hacia `l2.lineage2sudamerica.com:2106`.
- **Orquestación declarativa**:
  - [`config/servers.json`](../config/servers.json) declara `executable: system/L2.exe`, `runner: wine-11.22-staging-amd64` y `auth_proxy`.
  - [`scripts/l2_ctl.sh`](../scripts/l2_ctl.sh) levanta el relay automáticamente antes de ejecutar Wine y lo detiene al cerrar el juego mediante `trap cleanup_run EXIT`.

## 3. Ejecución y tests

```bash
# Ejecutar tests automatizados (32/32)
python3 -m unittest discover -s tests -p "test_*.py" -v

# Lanzar L2 Sudamérica (Interface 3.0 + Wine 11.22-staging + Auth Relay)
./scripts/l2_ctl.sh run l2sudamerica-interlude
```

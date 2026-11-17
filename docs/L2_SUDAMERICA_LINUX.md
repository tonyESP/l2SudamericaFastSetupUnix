# L2 Sudamérica (Interlude) en Linux — Informe de Ingeniería

Este documento registra el diagnóstico completo, las optimizaciones gráficas, de red y dual-box, y la arquitectura final que ejecuta **L2 Sudamérica (Interlude x10)** de forma reproducible bajo Linux/Wine desde [`scripts/l2_ctl.sh`](../scripts/l2_ctl.sh).

## 1. Perfiles de Cliente y Cadena de Montaje

Se mantienen 3 perfiles declarativos en [`config/servers.json`](../config/servers.json) y [`config/downloads.json`](../config/downloads.json):

1. **`l2sudamerica-interlude` (Fallback Seguro / WineD3D)**:
   - Base limpia de Interlude + sincronización oficial de `updater.ini`.
   - Parche [`tools/patches/D3DDrv.dll.noagp`](../tools/patches/D3DDrv.dll.noagp) cuando aplica sobre `system/D3DDrv.dll` para suprimir el modal bloqueante de AGP desactivado.
2. **`l2suda-optimizado` (Perfil Diario — Remaster Extreme)**:
   - DXVK 32-bit (`d3d9.dll`, `dxgi.dll`, GPL `Auto`, `numCompilerThreads = 4`, `maxFrameRate = 60`, `presentInterval = 0`, `maxFrameLatency = 1`, `latencySleep = True`, `allowFse = False`, `deviceLossOnFocusLoss = False`, `samplerAnisotropy = 16`, `samplerLodBias = -0.25`).
   - `vkBasalt` 32-bit en swapchain Vulkan (`effects = smaa:tonemap:vibrance:curves:cas`, `Gamma = 0.96`, `Exposure = 0.04`, `Vibrance = 0.34`, `Contrast = 0.32`, `casSharpness = 0.45`, toggle en vivo **`Home`**).
   - `Option.ini`: `Gamma=1.000000`, `PostProc=0`, `GPUAnimation=False`, `AntiAliasing=0`, `L2WaterEffect.EffectType=2`, `[ClippingRange]` ampliado (`Terrain=10`, `Actor=8`, `StaticMesh=8`, `StaticMeshLod=8`, `Pawn=6`).
3. **`l2suda-asedio` (Perfil Asedio / Mass PvP Ultra-FPS)**:
   - DXVK puro (`vkbasalt: false`, `samplerAnisotropy = 4`, `samplerLodBias = 0.0`).
   - `Option.ini` optimizado para eliminar el cuello de botella de animación/UI en CPU (`ModelDetail=1`, `SkipAnim=1`, `PawnShadow=False`, `RenderDeco=False`, `WeatherEffect=0`, `RenderActorLimited=2`, `L2WaterEffect.IsUseEffect=False`, `Pawn=3.0`, música/voz `.ogg` a `0.0`, y sin textos flotantes `HP+/MP+/CP+/EXP+`).

### Hallazgos Críticos de Estabilidad (Verificados)
- `PostProc=3` (HDR nativo UE2.5) provoca GPF en `FD3DRenderInterface::SetPixelShaderConstant <- UHDREffect::PostRender`.
- `GPUAnimation=True` provoca crashes al cambiar de zona/ciudad.
- `DisplayDepth.fx` con `depthCapture=on` confirmó buffer de profundidad vacío antes de presentar (`purple/white` sólido), descartando efectos dependientes de profundidad (MXAO).
- `FakeHDR.fx` + `casSharpness=0.72` + `LOD bias -0.5` + `deband` posterior generan trama/moiré sobre DXT 2006.
- **`l2_ctl.sh` Crash-Guard**: antes de cada lanzamiento fuerza `UseAGP=False`, `GPUAnimation=False`, `PostProc=0` y `StartupFullScreen=False` preservando saltos CRLF en `Option.ini`.

---

## 2. Solución al Bloqueo de Login (`WSAAsyncSelect`) y Red Transatlántica

### Diagnóstico de Login y Latencia Real (`45.235.99.29`)
- `l2.lineage2sudamerica.com` (`45.235.99.29`, Argentina) tiene un suelo físico (`minrtt` BBR medido en vivo con `ss -tin`) de **~270.5 ms** y un SYN-proxy anti-DDoS en el puerto `2106`.
- Wine sobrescribía `WSAAsyncSelect(FD_CONNECT)` con `FD_READ` antes de recibir el `SYN-ACK`, bloqueando el login.
- Además, las capturas en vivo sobre el puerto `7777` mostraron **`ato:40`** (Delayed ACK de Linux de hasta 40 ms), que penalizaba el encadenado rápido de paquetes de *target* (`Action` → `MyTargetSelected`) y *skills*.

### Implementación Por Socket (`LD_PRELOAD` + Proxy)
- **Shim C 32/64-bit (`tools/shims/l2_auth_redir.c`)**:
  - Redirige puerto `2106` a `127.0.0.1:L2_AUTH_PROXY_PORT` (`21060`, `21061`... en dual-box).
  - Por cada socket `AF_INET` (preservando `errno` de `EINPROGRESS` y sin tocar `sysctl` globales): aplica `TCP_NODELAY=1` (blindado en `setsockopt()`), `TCP_THIN_LINEAR_TIMEOUTS=1`, `IP_TOS=0xb8` (DSCP EF / Wi-Fi WMM Voz `AC_VO`) y rastrea hasta 8 FDs IPv4 en `g_ipv4_fds` para re-armar **`TCP_QUICKACK=1`** tras cada `recv`/`recvfrom`/`recvmsg` (ignorando sockets IPC de `wineserver`).
- **Relay TCP (`scripts/l2_auth_proxy.py`)**: aplica los mismos flags por socket en ambos extremos (`_tune_tcp_socket` + `TCP_QUICKACK` continuo).
- **Telemetría persistente**: `l2_ctl.sh` muestrea cada 30 s `ss -tin state established '( dport = :7777 )'` hacia `net_telemetry.log` (recortado a 200 líneas al salir).

---

## 3. Dual-Box, Ergonomía e Instalador Reproducible

- **Pinning de CPU y Dual-Box**: 1.ª instancia fijada a núcleos físicos primarios (`0..7`), 2.ª instancia a hilos SMT (`8..15`), puerto de auth relay auto-incrementado, omisión de `ram_prewarm` redundante y **silenciado automático de audio** en la 2.ª ventana (`winepulse.drv=d;winealsa.drv=d`).
- **Sincronización de UI/Barras/Crests**: `l2_ctl.sh` sincroniza bidireccionalmente con `cp -pu` `WindowsInfo.ini`, `iwo/*` y `crest/*` entre `l2suda-optimizado` y `l2suda-asedio`.
- **Ratón lineal 1:1**: `scripts/provision_prefix.sh` desactiva aceleración (`MouseSpeed=0`, `MouseThreshold1=0`, `MouseThreshold2=0` en `user.reg`).
- **Lanzadores e Icono**: icono extraído de `L2.exe` en [`config/l2-icon.png`](../config/l2-icon.png) y accesos `.desktop` en `config/` para diario y asedios.
- **Plantillas Git**: [`config/dxvk.conf.template`](../config/dxvk.conf.template), [`config/dxvk.siege.conf.template`](../config/dxvk.siege.conf.template), [`config/Option.optimized.ini.template`](../config/Option.optimized.ini.template), [`config/Option.siege.ini.template`](../config/Option.siege.ini.template) y [`config/vkBasalt.conf.template`](../config/vkBasalt.conf.template), inyectadas dinámicamente con [`scripts/apply_tuning.sh`](../scripts/apply_tuning.sh).

## 4. Ejecución y Verificación

```bash
# Ejecutar tests automatizados (35/35)
python3 -m unittest discover -s tests -p "test_*.py" -v

# Lanzar L2 Sudamérica (Diario Remaster / Asedio / Fallback)
./scripts/l2_ctl.sh run l2suda-optimizado
./scripts/l2_ctl.sh run l2suda-asedio
./scripts/l2_ctl.sh run l2sudamerica-interlude
```

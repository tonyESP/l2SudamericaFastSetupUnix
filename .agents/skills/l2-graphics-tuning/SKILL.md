---
name: l2-graphics-tuning
description: Perfil gráfico seguro de máxima calidad en modo ventana para Lineage 2 bajo WineD3D y configuración de teclas F1-F12 en portátiles Linux.
---

# L2 Graphics & Input Tuning (WineD3D / Linux)

Guía de configuración estable para obtener máxima nitidez y distancia de dibujado en Lineage 2 Interlude bajo WineD3D sin provocar crashes de shaders ni bloqueos de teclado en portátil.

## 1. Perfil seguro de máxima calidad en `system/Option.ini`

Bajo **WineD3D** (cuando `d3d9` nativo/DXVK no es compatible con el binario del servidor), se pueden subir al máximo texturas, modelos y distancia de dibujado, pero **hay que evitar** las opciones de shader/postprocesado que rompen `D3DDrv.dll`:

- **Seguras al máximo**:
  - `TextureDetail=0` (máxima resolución de texturas)
  - `ModelDetail=0` (máximo detalle de modelos)
  - `TerrainClippingRange` y `PawnClippingRange` altos
  - `UseTrilinear=True`, `UseSpecular=True`
- **Modo ventana 1080p**:
  - `StartupFullScreen=False`
  - `GamePlayViewportX=1920`, `GamePlayViewportY=1008` (o resolución útil sin tapar barra)
- **Obligatorias para estabilidad (evitar GPF)**:
  - `UseAGP=False` (complementado con `D3DDrv.dll.noagp`)
  - `GPUAnimation=False` (evita crash en `UD3DRenderDevice::GetVertexShader`)
  - `PostProc=0`
  - `AntiAliasing=0`

## 2. Teclas de función `F1`–`F12` en portátiles (HP ZBook / Action Keys)

### Síntoma
- El juego no detecta `F1`, `F2`, `F3`... directamente porque el teclado envía teclas multimedia (`Brillo`, `Volumen`, etc.) salvo que se pulse `Fn`.

### Solución
1. **Atajo rápido (`Fn Lock`)**: probar `Fn + Shift` o `Fn + Esc` según modelo de portátil.
2. **Solución permanente (BIOS)**: en HP ZBook Fury G8 entrar en BIOS (`F10`) -> `Advanced` -> `Built-In Device Options` -> desactivar **`Action Keys Mode`** (`Disabled`). Con esto `F1`–`F12` funcionan directos en L2 y las teclas multimedia pasan a usar `Fn`.

## 3. Perfil Avanzado DXVK + vkBasalt + MangoHud (Ban-Safe)

Para llevar el cliente más allá de WineD3D sin tocar `l2.ini` (cifrado RSA) ni paquetes `.utx`:

- **DXVK (`dxvk.conf`)**:
  - `d3d9.maxFrameRate = 60` (ajustado al panel real `60.06 Hz` para evitar *thermal throttling*).
  - `d3d9.presentInterval = 0`, `d3d9.maxFrameLatency = 1`, `dxvk.latencySleep = True`.
  - `dxvk.allowFse = False`, `d3d9.deviceLossOnFocusLoss = False` (evita cuelgues al cambiar de ventana / Alt+Tab).
  - `d3d9.samplerAnisotropy = 16`, `d3d9.samplerLodBias = -0.25`, `d3d9.clampNegativeLodBias = False`, `d3d9.seamlessCubes = True`, `dxvk.numCompilerThreads = 4` (evita *shimmer*/trama en DXT de 2006 y contención de hilos en dual-box).
- **Sistema y Red (`l2_ctl.sh`)**:
  - Pinning Dual-Box automático (`taskset` + `WINE_CPU_TOPOLOGY`): 1.ª instancia en hilos primarios (`0..7`), 2.ª instancia en hilos SMT (`8..15`), puerto del auth relay auto-incrementado (`21060`, `21061`, ...), omisión de `ram_prewarm` redundante si ya hay `L2.exe` activo, `gamemoderun`, `TCP_NODELAY` en `l2_auth_redir.so` (32 y 64 bits con `$LIB`) y `MangoHud` con `fps_metrics=0.01`.
- **Post-procesado Vulkan 32-bit (`vkBasalt` en `l2sudamerica-lab`)**:
  - **Perfil anterior (backup `vkBasalt.conf.bak-remaster`)**: `effects = deband:smaa:vibrance:curves:cas` (`Vibrance=0.38`, `Contrast=0.45`, `casSharpness=0.65`).
  - **Perfil Remaster Extreme actual (graduado a `l2sudamerica-optimized` y activo en `l2sudamerica-lab`)**: `effects = smaa:tonemap:vibrance:curves:cas` (sin `deband` para no suavizar el micro-detalle de `cas`; `Tonemap` `Gamma=0.96`/`Exposure=0.04`/`Saturation=0.08`/`Defog=0.0` emparejado con `Gamma=1.000000` neutro en `Option.ini`, `Vibrance=0.34`, `Contrast=0.32`, `casSharpness=0.45`, toggle en vivo con `Home`).
  - **Motor UE2.5 (`clients/l2sudamerica-lab/system/Option.ini`, backup `Option.ini.bak-remaster`)**: `Gamma=1.000000`, `PostProc=1`, `L2WaterEffect.EffectType=2`, `[ClippingRange]` ampliado (`Terrain=10`, `Actor=8`, `StaticMesh=8`, `StaticMeshLod=8`, `Pawn=6`).
  - Mantener `AntiAliasing=0` y `GPUAnimation=False` en `Option.ini` (con `GPUAnimation=True` crashea en Gatekeeper/ciudad; `AntiAliasing>0` puede bloquear `depthCapture` en Vulkan/DXVK).


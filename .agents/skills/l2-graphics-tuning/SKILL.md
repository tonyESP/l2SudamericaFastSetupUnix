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

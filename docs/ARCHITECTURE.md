# Arquitectura del Sistema de Ejecución y Automatización de L2

Este documento describe la arquitectura de software, aislamiento y ejecución desatendida desarrollada para ejecutar múltiples clientes de Lineage 2 sobre Linux.

---

## 1. Diagrama de Aislamiento y Componentes

Para permitir probar distintas crónicas y servidores sin conflictos de configuración, DLLs o archivos de registro, se aplica un modelo de **prefijos Wine aislados por perfil**:

```text
/mnt/disk4u/L2/
│
├── config/
│   └── servers.json              <── Declaración de servidores y parámetros
│
├── scripts/
│   ├── l2_ctl.sh                 <── CLI central de aprovisionamiento y ejecución
│   ├── env.sh                    <── Variables de GPU NVIDIA y paths globales
│   ├── provision_prefix.sh       <── Generador desatendido de Wineprefix + Winetricks
│   └── apply_tuning.sh           <── Inyector de configuración gráfica y L2.ini
│
├── tools/
│   └── runners/
│       └── GE-Proton / Wine-GE   <── Capa de ejecución binaria unificada
│
├── prefixes/                     <── Aislamiento de entorno de Windows
│   ├── elmorelab_erica/          <── Prefijo dedicado (tahoma, dx9, msxml4)
│   └── l2frenzy_x10/             <── Prefijo dedicado independiente
│
└── clients/                      <── Datos estáticos del juego (assets, system)
    ├── elmorelab_erica/
    └── l2frenzy_x10/
```

---

## 2. Pipeline Gráfico y Aceleración por Hardware

El equipo cuenta con una arquitectura híbrida Intel TigerLake + NVIDIA T1200 Laptop GPU. Para garantizar que el cliente corra sobre la GPU dedicada sin requerir intervención manual:

```bash
# Variables inyectadas automáticamente por scripts/env.sh:
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export DXVK_LOG_LEVEL=none
export DXVK_STATE_CACHE=1
export DXVK_STATE_CACHE_PATH=/mnt/disk4u/L2/tools/dxvk_cache
```

1. **DirectX 9**: El ejecutable original `l2.exe` emite llamadas Direct3D 9.
2. **DXVK**: Intercepta `d3d9.dll` y compila los shaders y estados de renderizado a **Vulkan 1.3**.
3. **NVIDIA Driver 615**: La GPU Turing procesa el stream Vulkan nativo con latencia mínima.

---

## 3. Principio de Aprovisionamiento Desatendido

El objetivo del proyecto es que la preparación de un nuevo servidor se ejecute con un solo comando:

```bash
./scripts/l2_ctl.sh setup <server_id>
```

Pasos ejecutados de forma automática:
1. Comprueba si el runner (Wine-GE/Proton-GE) está disponible; si falta, lo descarga y descomprime en `tools/runners/`.
2. Inicializa el `WINEPREFIX` en `/mnt/disk4u/L2/prefixes/<server_id>`.
3. Instala silenciosamente las dependencias de Winetricks:
   - `corefonts` y `tahoma` (renderizado tipográfico del chat e interfaz).
   - `d3dx9` (librerías matemáticas de DirectX).
   - `vcrun2008` (runtime de C++ de Microsoft).
   - `msxml4` (parser XML para ventanas de inventario y habilidades).
4. Copia plantillas de `dxvk.conf` y `Option.ini` con optimización de resolución y tasa de refresco.

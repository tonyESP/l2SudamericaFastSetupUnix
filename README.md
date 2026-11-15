# Lineage 2 - Linux Gaming Setup (/mnt/disk4u/L2)

Este directorio está preparado para alojar el cliente, prefijo de Wine y herramientas necesarias para jugar a **Lineage 2 en Linux** sin problemas de compatibilidad ni anticheats intrusivos.

---

## 📁 Estructura de Directorios

- `clients/`: Directorio donde se descomprime el cliente del juego (ej: `/mnt/disk4u/L2/clients/elmorelab_interlude`).
- `prefixes/`: Prefijo(s) de Wine de 32/64 bits independientes (ej: `/mnt/disk4u/L2/prefixes/l2_interlude`).
- `tools/`: Runners (Wine-GE, Proton-GE) y scripts de arranque optimizados.
- `downloads/`: Archivos comprimidos, parches y paquetes de instalación.

---

## ⚔️ Servidor Recomendado: ElmoreLab (Interlude - Erica x3)

- **Crónica**: Interlude (C6).
- **Rates**: x3.
- **Filosofía**: Cero Pay-to-Win, progresión clásica por fases, anti-bot en servidor (sin drivers de kernel).
- **Compatibilidad Linux**: 100% nativa con Wine-GE / Proton-GE + DXVK.
- **Web oficial**: https://elmorelab.com

---

## ⚙️ Dependencias Clave de Winetricks para el Prefijo

Para evitar crasheos en la interfaz o fuentes corruptas:
```bash
winetricks corefonts tahoma d3dx9 vcrun2008 msxml4
```

- `tahoma / corefonts`: Evita textos en blanco o cuadros en la UI.
- `d3dx9`: Librerías nativas DirectX 9 traducidas por DXVK.
- `vcrun2008`: Runtime de C++ para el motor de L2.
- `msxml4`: Evita crasheos al abrir inventario, mapa o ventanas de habilidades (lector XML).

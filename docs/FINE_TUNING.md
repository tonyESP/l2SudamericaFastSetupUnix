# Guía de Fine-Tuning: Optimización de Motor y Rendimiento para Lineage 2

Este documento detalla las modificaciones y parámetros recomendados para maximizar la tasa de cuadros, eliminar el micro-stuttering en ciudades y optimizar la legibilidad de la interfaz en pantallas modernas.

---

## 1. Optimización del Motor Unreal Engine 2.5 (`L2.ini`)

Por defecto, los clientes antiguos de L2 vienen configurados para ordenadores de los años 2004-2007 (con 512 MB de RAM total). En un sistema moderno con 64 GB de RAM y NVIDIA T1200, podemos desbloquear el motor:

### Aumento de Cache de Texturas y Geometría
En la sección `[Engine.GameEngine]`:
```ini
; Por defecto venía en 32 MB, provocando tirones continuos al cargar personajes en Giran o Aden.
CacheSizeMegs=512
```

### Reducción de Latencia de Cliente y Red
```ini
; Reduce la espera entre frames de renderizado y bucle de red
MinClientDelay=1
UseNVIDIAStereo=False
```

---

## 2. Configuración de DXVK (`dxvk.conf`)

DXVK traduce DirectX 9 a Vulkan. Ubicando un archivo `dxvk.conf` junto al ejecutable `l2.exe` o definiendo la variable `DXVK_CONFIG_FILE`:

```ini
# Límite de FPS para evitar que la GPU trabaje innecesariamente a 400 FPS en menús
d3d9.maxFrameRate = 144

# Filtro anisotrópico forzado a x16 (suaviza texturas del suelo a distancia sin coste en GPU)
d3d9.samplerAnisotropy = 16

# Optimización de buffers de superficie para evitar parpadeos al minimizar o hacer Alt+Tab
d3d9.deferSurfaceCreation = True

# Cache asíncrona de shaders (elimina el stutter la primera vez que se lanza un hechizo)
dxvk.enableAsync = True
```

---

## 3. Optimización de Resolución e Interfaz (`Option.ini`)

Para que el juego arranque en pantalla completa o ventana sin bordes a 1080p:

```ini
[Video]
StartupResolutionX=1920
StartupResolutionY=1080
ColorBits=32
RefreshRate=60
LOD=0
TextureDetail=0
SkinDetail=0
Shadow=1
Weather=0
EffectLimit=0
```

---

## 4. Tipografía y Fuentes (Solución al "Bug de las Letras Borrosas o Cuadros")

El cliente de L2 depende estrictamente de la fuente **Tahoma** de Windows. Si el prefijo Wine no la encuentra, utiliza fuentes sustitutas de Linux que no respetan el espaciado de celdas del chat y los menús, provocando que el texto se corte.

* Solución automatizada: `scripts/provision_prefix.sh` inyecta automáticamente `tahoma.ttf` y `tahomabd.ttf` en `windows/Fonts/`.

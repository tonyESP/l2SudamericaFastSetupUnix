# Estudio de Ingeniería: Rates y Matriz de Servidores de Lineage 2

Este documento analiza con criterio cuantitativo y cualitativo el impacto de los **rates**, la elección de la **crónica**, la viabilidad técnica en **Linux** (filtro de anticheat) y los candidatos recomendados para testeo.

---

## 1. El Dilema de los Rates: ¿Dónde está el "Punto Dulce"?

El multiplicador de rates define la economía, el tiempo de inversión y la dinámica social del juego:

| Rango de Rates | Perfil de Juego | Progresión al Endgame | Economía y Crafteo | Viabilidad Solo / Dúo | Vida Media del Servidor |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Low-Rate (x1 - x3)** *(Hardcore)* | Purista / Nostálgico | 6 a 12 meses de grind diario | Crítica: cada adena, receta y pieza cuenta | Muy baja: requiere CP (Constant Party) de 9 personas y buffers dedicados | Muy alta (años sin wipes) |
| **Mid-Rate (x6 - x10)** *(Punto Dulce)* | Competitivo / Adulto con tiempo limitado | 3 a 6 semanas para grado A/S | Activa: crafteo y spoil tienen valor real sin ser un trabajo a tiempo completo | **Alta**: viable con dualbox o clan pequeño | Media-Alta (temporadas largas o resets cíclicos) |
| **Craft-PvP (x15 - x30)** | Dinámico / Acción rápida | 1 a 2 semanas | Moderada: NPC buffers suelen reemplazar a soportes; foco en materiales de enchant | Muy alta: no dependes de party fija | Media (3 a 6 meses por ciclo) |
| **High-Rate (x50 - x1000)** | Full PvP / Instantáneo | Días u horas | Nula: GM Shop vende todo por adena o medallas | Total | Baja (wipes frecuentes) |

### Conclusión sobre Rates
Para un jugador que busca **disfrutar de la progresión, el crafteo y el mercado sin hipotecar su vida**, el rango **x6 - x10** representa el balance óptimo:
- Elimina el sufrimiento de farmear 40 horas para una pieza Grado C/B.
- Mantiene la emoción de dropear un arma, encantarla y disputar bosses.
- Permite competir en asedios y Olimpiadas en un plazo razonable.

---

## 2. El Filtro Crítico de Linux: Arquitectura Anti-Cheat

En Linux, la compatibilidad no depende de la potencia gráfica, sino de cómo el servidor valida la integridad del cliente:

```
[ Cliente L2 (DirectX 9 / UE 2.5) ]
                │
         (Llamadas Win32)
                │
                ▼
        [ Capa Wine / Proton ] ──► [ DXVK (Vulkan 1.3) ] ──► [ GPU NVIDIA T1200 ]
                │
        ¿Hay Anti-Cheat?
        ├── SI (SmartGuard / Strix / AAC a nivel Kernel) ──► ❌ CRASH / BAN (No emulable en Wine)
        └── NO / Server-Side (Validación en backend)      ──► ✅ 100% FUNCIONAL Y FLUIDO
```

---

## 3. Matriz de Candidatos para el Banco de Pruebas

Para que puedas comparar y juzgar de primera mano, establecemos 4 candidatos clave:

### Candidato 1: ElmoreLab - Erica (Interlude x3)
- **Crónica**: Interlude (Unreal Engine 2.5 puro).
- **Rates**: Exp/Sp x3, Adena x3, Drop/Spoil x3.
- **Anti-Cheat**: 100% Server-Side. **Compatibilidad Linux: 10/10**.
- **Ventajas**: Máxima estabilidad, economía blindada contra P2W, progresión pausada por fases.
- **Desventaja**: El ritmo x3 requiere paciencia.

### Candidato 2: L2 Frenzy / Oryn / Mythos (Interlude x6 - x10)
- **Crónica**: Interlude.
- **Rates**: x6 - x10 (Mid-Rate / Craft-PvP).
- **Anti-Cheat**: Protección Win32 estándar (Wine friendly). **Compatibilidad Linux: 9/10**.
- **Ventajas**: Ritmo perfecto para jugar en solitario o dúo, buffers de apoyo, teleports accesibles.
- **Desventaja**: Duración estacional de los ciclos.

### Candidato 3: L2 Classic Club (Classic 2.7 Savior)
- **Crónica**: Classic (Motor moderno de L2 con mapa y mecánicas tradicionales).
- **Rates**: x3 (progresión acelerada en early game mediante quests).
- **Anti-Cheat**: Launcher compatible mediante Proton-GE. **Compatibilidad Linux: 8/10**.
- **Ventajas**: Interfaz moderna, gráficos mejorados, balance de clases renovado.
- **Desventaja**: Curva de aprendizaje respecto a Interlude clásico.

### Candidato 4: L2 Scarlet / Freya-H5 (High Five x15)
- **Crónica**: High Five (Part 5).
- **Rates**: x15 (Mid-Rate).
- **Anti-Cheat**: Sin SmartGuard. **Compatibilidad Linux: 8/10**.
- **Ventajas**: Permite explorar el "pico" de habilidades, atributos e instancias de H5.
- **Desventaja**: Menos población que los reinos de Interlude masivos.

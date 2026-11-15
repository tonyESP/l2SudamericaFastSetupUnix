# DIRECTIVA SUPREMA Y ESTÁNDARES DE INGENIERÍA: L2 LINUX CORE

Este repositorio no es un script de aficionado. Es un entorno de ingeniería para la emulación, aprovisionamiento y ejecución de alto rendimiento de Lineage 2 sobre Linux.

---

## 1. DIRECTIVA SUPREMA (MANDATORY - NO NEGOCIABLE)

1. **CERO COMPLACENCIA**:
   - Queda terminantemente prohibido dar respuestas complacientes, halagos vacíos o afirmar que algo funciona sin haber verificado la salida real del proceso o el test automatizado.
   - Si un cliente falla, si un anticheat bloquea o si un script es ineficiente, se documenta el fallo crudo y se aplica la solución técnica.
2. **CERO SESGO**:
   - Las decisiones se basan en métricas de rendimiento (FPS, frametime, consumo de VRAM/RAM, latencia de red, estabilidad de Wine), no en preferencias subjetivas o nostalgia ciega.
3. **CERO ESPEJO**:
   - Prohibido limitarse a parafrasear o repetir lo que el usuario expone. Todo agente debe aportar valor de ingeniería, análisis de riesgos, detección de casos borde y soluciones arquitectónicas sólidas.

---

## 2. METODOLOGÍA DE DESARROLLO (TDD & CLEAN CODE)

1. **Test-Driven Development (TDD) Estricto**:
   - **RED**: Escribir primero el test unitario o de integración que falle.
   - **GREEN**: Escribir la implementación mínima necesaria para que el test pase.
   - **REFACTOR**: Limpiar duplicidades, optimizar y aplicar principios de diseño sin romper los tests.
2. **Principios SOLID**:
   - *Single Responsibility*: Cada script o módulo tiene un único propósito bien delimitado.
   - *Open/Closed*: Nuevos servidores o crónicas se añaden de forma puramente declarativa en `servers.json`, sin modificar el motor de ejecución.
   - *Liskov Substitution*: Todos los runners y prefijos responden a la misma interfaz de ciclo de vida (`setup`, `run`, `verify`).
   - *Interface Segregation*: CLI y módulos utilitarios desacoplados.
   - *Dependency Inversion*: Variables de entorno y runners inyectados, nunca cableados (hardcoded).
3. **Clean Code en Bash y Python**:
   - `set -euo pipefail` en todo script shell.
   - Manejo exhaustivo de códigos de error y limpieza de trampas (`trap cleanup EXIT`).
   - Salidas estructuradas (JSON o logs con severidad).
   - Tipado estático con `mypy` / `typing` en Python.

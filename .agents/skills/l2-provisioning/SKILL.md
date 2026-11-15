---
name: l2-provisioning
description: Procedimiento de ingeniería para aprovisionar, verificar y optimizar clientes de Lineage 2 bajo Linux con Wine-GE y DXVK.
---

# L2 Provisioning & Benchmark Runbook

Este runbook describe el protocolo técnico estándar para desplegar un nuevo cliente de Lineage 2 en el banco de pruebas.

## 1. Verificación de Requisitos Previos (Healthcheck)
1. Ejecutar `./scripts/l2_ctl.sh doctor` para comprobar GPU NVIDIA activa y driver Vulkan 1.3.
2. Comprobar que el runner Wine-GE está en `tools/runners/current`.

## 2. Declaración del Servidor
Añadir la entrada correspondiente en `config/servers.json` con:
- `id`: Identificador canónico (kebab-case).
- `chronicle`: Versión exacta del cliente.
- `rates`: Multiplicadores EXP, SP, Adena, Spoil.
- `client_dir` y `prefix_dir`.
- `winetricks`: Array de dependencias (`corefonts`, `tahoma`, `d3dx9`, `vcrun2008`, `msxml4`).

## 3. Aprovisionamiento Desatendido del Prefijo
Ejecutar:
```bash
./scripts/l2_ctl.sh setup <server_id>
```
El procedimiento:
- Crea un `WINEPREFIX` Win32 limpio.
- Instala las DLLs de DirectX 9 y runtimes de C++ requeridos.
- Inyecta `dxvk.conf` con async shaders y límite de framerate.
- Genera el `Option.ini` con resolución de pantalla completa/1080p.

## 4. Validación mediante Tests Automatizados
Ejecutar la suite de tests en `tests/`:
```bash
python3 -m unittest discover -s tests -p "test_*.py"
```
Verificar que todos los tests unitarios e integrados pasan antes de autorizar la ejecución.

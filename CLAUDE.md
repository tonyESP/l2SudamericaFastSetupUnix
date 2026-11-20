# CLAUDE.md — AI Agent Guide for Lineage 2 Sudamérica Linux Core

See `AGENTS.md` for full engineering standards and architectural invariants.

## Quick Setup Command
```bash
./quick_setup.sh --non-interactive
```
*(Accepts `--client-path <path_to_client_or_rar>` if client is stored outside).*

## Verification & Diagnostics
```bash
./scripts/l2_ctl.sh doctor
python3 -m unittest discover -s tests -p "test_*.py" -v
```

## Running the Game
- Daily Remaster (60 FPS): `./scripts/l2_ctl.sh run l2suda-optimizado`
- Siege / Ultra-FPS:       `./scripts/l2_ctl.sh run l2suda-asedio`
- Sync Official Updates:   `./scripts/l2_ctl.sh update`
- Stop all instances:      `./scripts/l2_ctl.sh stop all`

## Strict Invariants
1. Never commit `clients/`, `prefixes/`, `downloads/`, `.env`, or `.rar`/`.zip`/`.7z`/`.tar.*` archives.
2. 100% Ban-Safe: never modify `.utx`, `l2.ini`, or `L2.exe`. All tuning is injected via DXVK, Option.ini, vkBasalt, and socket shims.
3. Keep `StartupFullScreen=False`, `UseAGP=False`, `GPUAnimation=False`, `PostProc=0` to prevent UE2.5 GPF crashes.

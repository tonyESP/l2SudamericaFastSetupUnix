#!/usr/bin/env python3
"""Case-insensitive MD5 sync client and AGP patcher for L2 Sudamerica updater.ini."""

import argparse
import concurrent.futures
import gzip
import hashlib
import os
import shutil
import sys
import urllib.request
from typing import List, Optional, Tuple

DEFAULT_BASE_URL = "http://l2updates.com/sudamerica/updater/"

JMP_OFFSET = 0x1C437
JMP_ORIG = b"\x39\x30"
JMP_PATCH = b"\xeb\x6f"

MSG_OFFSET = 0x1C4A2
MSG_ORIG = b"\xff\x15\x74\xd6\x0d\x10"
MSG_PATCH = b"\x31\xc0\x90\x90\x90\x90"


def _file_md5(path: str) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def _is_noagp_patched(dll_path: str) -> bool:
    if not os.path.isfile(dll_path):
        return False
    with open(dll_path, "rb") as f:
        f.seek(JMP_OFFSET)
        cur_jmp = f.read(len(JMP_PATCH))
        f.seek(MSG_OFFSET)
        cur_msg = f.read(len(MSG_PATCH))
    return cur_jmp == JMP_PATCH and cur_msg == MSG_PATCH


def patch_noagp(dll_path: str, backup: bool = True) -> str:
    """Patch D3DDrv.dll in place to skip the AGP deactivation warning dialog."""
    with open(dll_path, "rb") as f:
        data = bytearray(f.read())

    if len(data) <= MSG_OFFSET + len(MSG_ORIG):
        raise ValueError(f"Unexpected D3DDrv.dll size: {len(data)}")

    cur_jmp = bytes(data[JMP_OFFSET : JMP_OFFSET + len(JMP_ORIG)])
    cur_msg = bytes(data[MSG_OFFSET : MSG_OFFSET + len(MSG_ORIG)])

    if cur_jmp == JMP_PATCH and cur_msg == MSG_PATCH:
        return "already_patched"

    if cur_jmp != JMP_ORIG or cur_msg != MSG_ORIG:
        raise ValueError(
            f"Unsupported D3DDrv.dll bytes at AGP check: {cur_jmp.hex()} / {cur_msg.hex()}"
        )

    if backup:
        orig_path = dll_path + ".orig"
        shutil.copy2(dll_path, orig_path)

    data[JMP_OFFSET : JMP_OFFSET + len(JMP_PATCH)] = JMP_PATCH
    data[MSG_OFFSET : MSG_OFFSET + len(MSG_PATCH)] = MSG_PATCH

    with open(dll_path, "wb") as f:
        f.write(data)
    return "patched"


def parse_updater_ini(raw_text: str) -> List[Tuple[str, str, int]]:
    """Parse updater.ini lines into (md5_upper, rel_path, expected_size)."""
    entries: List[Tuple[str, str, int]] = []
    for line in raw_text.splitlines():
        line = line.strip()
        if not line or "|" not in line or line.startswith(("Version|", "Bytes|")):
            continue
        md5_hex, rel_path, size_str = line.split("|", 2)
        entries.append((md5_hex.upper(), rel_path, int(size_str)))
    return entries


def resolve_case_insensitive(base_dir: str, rel_path: str) -> str:
    """Resolve rel_path inside base_dir matching existing casing on Linux ext4."""
    parts = rel_path.replace("\\", "/").split("/")
    cur = base_dir
    for idx, part in enumerate(parts):
        if os.path.isdir(cur):
            entries = {entry.lower(): entry for entry in os.listdir(cur)}
            if part.lower() in entries:
                cur = os.path.join(cur, entries[part.lower()])
                continue
        cur = os.path.join(cur, *parts[idx:])
        break
    return cur


def _matches_expected_or_patched_d3ddrv(target: str, rel_path: str, md5_exp: str) -> bool:
    if os.path.isfile(target) and _file_md5(target) == md5_exp:
        return True
    if rel_path.lower() == "system\\d3ddrv.dll" and _is_noagp_patched(target):
        orig = target + ".orig"
        if os.path.isfile(orig) and _file_md5(orig) == md5_exp:
            return True
    return False


def _ensure_d3ddrv_patched(client_dir: str) -> None:
    dll_path = resolve_case_insensitive(client_dir, "system\\D3DDrv.dll")
    if not os.path.isfile(dll_path):
        return
    try:
        status = patch_noagp(dll_path)
        print(f"[UPDATER] D3DDrv.dll ({os.path.basename(client_dir)}): {status}")
    except ValueError as exc:
        print(f"[WARN] No se pudo parchear {dll_path}: {exc}", file=sys.stderr)


def sync_client(
    client_dir: str,
    base_url: str = DEFAULT_BASE_URL,
    skip_d3d9: bool = True,
    workers: int = 6,
    mirror_dirs: Optional[List[str]] = None,
) -> Tuple[int, int, int, int]:
    """Download, MD5-verify, re-patch D3DDrv.dll, and optionally mirror to peer dirs."""
    req = urllib.request.Request(
        base_url + "updater.ini", headers={"User-Agent": "L2SudamericaUpdater"}
    )
    ini_bytes = urllib.request.urlopen(req, timeout=30).read()
    with open(os.path.join(client_dir, "updater.ini"), "wb") as f:
        f.write(ini_bytes)

    entries = parse_updater_ini(ini_bytes.decode("utf-8", errors="replace"))
    pending: List[Tuple[str, str, str]] = []
    already_ok = 0

    for md5_exp, rel_path, _ in entries:
        if skip_d3d9 and rel_path.lower() == "system\\d3d9.dll":
            continue
        target = resolve_case_insensitive(client_dir, rel_path)
        if _matches_expected_or_patched_d3ddrv(target, rel_path, md5_exp):
            already_ok += 1
            continue
        pending.append((md5_exp, rel_path, target))

    def _download(item: Tuple[str, str, str]) -> str:
        md5_exp, rel_path, target = item
        url = base_url + rel_path.replace("\\", "/").replace(" ", "%20") + ".gzip"
        os.makedirs(os.path.dirname(target), exist_ok=True)
        dl_req = urllib.request.Request(url, headers={"User-Agent": "L2SudamericaUpdater"})
        raw = urllib.request.urlopen(dl_req, timeout=60).read()
        try:
            data = gzip.decompress(raw)
        except OSError:
            data = raw
        actual = hashlib.md5(data).hexdigest().upper()
        if actual != md5_exp:
            raise ValueError(f"MD5 mismatch for {rel_path}: {actual} != {md5_exp}")
        with open(target, "wb") as out:
            out.write(data)
        return rel_path

    downloaded = 0
    errors = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(_download, item): item[1] for item in pending}
        for fut in concurrent.futures.as_completed(futures):
            try:
                rel = fut.result()
                downloaded += 1
                print(f"[UPDATER] Actualizado: {rel}")
            except Exception as exc:
                errors += 1
                print(f"[ERR] {futures[fut]}: {exc}", file=sys.stderr)

    _ensure_d3ddrv_patched(client_dir)

    mirrored = 0
    for mdir in mirror_dirs or []:
        if not os.path.isdir(mdir):
            continue
        with open(os.path.join(mdir, "updater.ini"), "wb") as f:
            f.write(ini_bytes)
        for md5_exp, rel_path, _ in entries:
            if skip_d3d9 and rel_path.lower() == "system\\d3d9.dll":
                continue
            src = resolve_case_insensitive(client_dir, rel_path)
            dst = resolve_case_insensitive(mdir, rel_path)
            if not os.path.isfile(src):
                continue
            if _matches_expected_or_patched_d3ddrv(dst, rel_path, md5_exp):
                continue
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            if rel_path.lower() == "system\\d3ddrv.dll" and os.path.isfile(src + ".orig"):
                shutil.copy2(src + ".orig", dst + ".orig")
            shutil.copy2(src, dst)
            mirrored += 1
        _ensure_d3ddrv_patched(mdir)

    return already_ok, downloaded, mirrored, errors


def main(argv: Optional[List[str]] = None) -> int:
    """CLI entrypoint."""
    parser = argparse.ArgumentParser(description="Sync L2 Sudamerica client files")
    parser.add_argument("client_dir", help="Path to L2 client root directory")
    parser.add_argument(
        "--mirror-dir",
        action="append",
        default=[],
        help="Optional peer client directory to update from client_dir without extra downloads",
    )
    parser.add_argument("--keep-d3d9", action="store_true", help="Do not skip system/d3d9.dll")
    args = parser.parse_args(argv)

    ok, dl, mir, err = sync_client(
        args.client_dir,
        skip_d3d9=not args.keep_d3d9,
        mirror_dirs=args.mirror_dir,
    )
    print(
        f"[UPDATER] Completado: al_dia={ok}, descargados={dl}, espejados={mir}, errores={err}"
    )
    return 1 if err else 0


if __name__ == "__main__":
    sys.exit(main())

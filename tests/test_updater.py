#!/usr/bin/env python3
"""Unit tests for the integrated L2 Sudamerica updater (scripts/l2_updater.py)."""

import os
import subprocess
import sys
import tempfile
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SCRIPTS_DIR = os.path.join(PROJECT_ROOT, "scripts")
L2_CTL = os.path.join(SCRIPTS_DIR, "l2_ctl.sh")

if SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)


class TestL2Updater(unittest.TestCase):
    def test_parse_updater_ini_skips_headers_and_parses_entries(self):
        import l2_updater

        sample = (
            "Version|1\n"
            "Bytes|2102576988\n"
            "AA578B2FE930C6ECB1739AB5768DE1CA|system\\Engine.dll|30747136\n"
            "Bytes|0\n"
            "b66a86eaace402b8c8c01c08113f1360|system\\Npcgrp.dat|225584\n"
        )
        entries = l2_updater.parse_updater_ini(sample)
        self.assertEqual(
            entries,
            [
                ("AA578B2FE930C6ECB1739AB5768DE1CA", "system\\Engine.dll", 30747136),
                ("B66A86EAACE402B8C8C01C08113F1360", "system\\Npcgrp.dat", 225584),
            ],
        )

    def test_resolve_case_insensitive_matches_existing_files(self):
        import l2_updater

        with tempfile.TemporaryDirectory() as tmpdir:
            sys_dir = os.path.join(tmpdir, "system")
            os.makedirs(sys_dir)
            real_path = os.path.join(sys_dir, "npcgrp.dat")
            with open(real_path, "wb") as f:
                f.write(b"test")

            resolved = l2_updater.resolve_case_insensitive(tmpdir, "system\\Npcgrp.dat")
            self.assertEqual(resolved, real_path)

            new_path = l2_updater.resolve_case_insensitive(tmpdir, "textures\\CustomNew.utx")
            self.assertEqual(new_path, os.path.join(tmpdir, "textures", "CustomNew.utx"))

    def test_patch_noagp_idempotent(self):
        import l2_updater

        with tempfile.TemporaryDirectory() as tmpdir:
            dll_path = os.path.join(tmpdir, "D3DDrv.dll")
            buf = bytearray(l2_updater.MSG_OFFSET + len(l2_updater.MSG_ORIG) + 16)
            buf[l2_updater.JMP_OFFSET : l2_updater.JMP_OFFSET + len(l2_updater.JMP_ORIG)] = (
                l2_updater.JMP_ORIG
            )
            buf[l2_updater.MSG_OFFSET : l2_updater.MSG_OFFSET + len(l2_updater.MSG_ORIG)] = (
                l2_updater.MSG_ORIG
            )
            with open(dll_path, "wb") as f:
                f.write(buf)

            self.assertEqual(l2_updater.patch_noagp(dll_path), "patched")
            self.assertTrue(os.path.isfile(dll_path + ".orig"))
            with open(dll_path, "rb") as f:
                patched = f.read()
            self.assertEqual(
                patched[l2_updater.JMP_OFFSET : l2_updater.JMP_OFFSET + len(l2_updater.JMP_PATCH)],
                l2_updater.JMP_PATCH,
            )
            self.assertEqual(
                patched[l2_updater.MSG_OFFSET : l2_updater.MSG_OFFSET + len(l2_updater.MSG_PATCH)],
                l2_updater.MSG_PATCH,
            )
            self.assertEqual(l2_updater.patch_noagp(dll_path), "already_patched")

    def test_l2_ctl_usage_lists_update_command(self):
        res = subprocess.run([L2_CTL, "invalid_cmd"], capture_output=True, text=True)
        self.assertIn("update", res.stdout)


if __name__ == "__main__":
    unittest.main()

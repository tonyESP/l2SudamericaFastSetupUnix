#!/usr/bin/env python3
"""
Unit tests for Wine prefixes validation in Lineage 2 Linux Core.
Strict TDD verification of isolated prefixes structure, registry files, and DXVK configurations.
"""

import json
import os
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CONFIG_FILE = os.path.join(PROJECT_ROOT, "config", "servers.json")


class TestWinePrefixes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            cls.config = json.load(f)
        cls.servers = cls.config.get("servers", {})

    def test_all_servers_have_provisioned_prefixes(self):
        """Verifies that all declared servers have their dedicated Wine prefix provisioned."""
        self.assertGreater(len(self.servers), 0, "No servers defined in config")

        for server_id, server in self.servers.items():
            with self.subTest(server=server_id):
                prefix_rel = server.get("prefix_dir")
                self.assertIsNotNone(prefix_rel, f"prefix_dir not defined for {server_id}")

                prefix_path = os.path.join(PROJECT_ROOT, prefix_rel)
                self.assertTrue(
                    os.path.isdir(prefix_path),
                    f"Prefix directory missing for {server_id}: {prefix_path}"
                )

    def test_prefix_filesystem_structure(self):
        """Verifies essential Wine directory hierarchy (drive_c, dosdevices)."""
        for server_id, server in self.servers.items():
            with self.subTest(server=server_id):
                prefix_path = os.path.join(PROJECT_ROOT, server["prefix_dir"])
                
                # Check dosdevices directory
                dosdevices_dir = os.path.join(prefix_path, "dosdevices")
                self.assertTrue(
                    os.path.isdir(dosdevices_dir),
                    f"dosdevices missing in prefix for {server_id}: {dosdevices_dir}"
                )

                # Check drive_c directory
                drive_c_dir = os.path.join(prefix_path, "drive_c")
                self.assertTrue(
                    os.path.isdir(drive_c_dir),
                    f"drive_c missing in prefix for {server_id}: {drive_c_dir}"
                )

    def test_prefix_registry_files(self):
        """Verifies that core Wine registry databases (system.reg, user.reg) exist and are non-empty."""
        for server_id, server in self.servers.items():
            with self.subTest(server=server_id):
                prefix_path = os.path.join(PROJECT_ROOT, server["prefix_dir"])

                system_reg = os.path.join(prefix_path, "system.reg")
                self.assertTrue(
                    os.path.isfile(system_reg),
                    f"system.reg missing in prefix for {server_id}: {system_reg}"
                )
                self.assertGreater(
                    os.path.getsize(system_reg),
                    0,
                    f"system.reg is empty in prefix for {server_id}"
                )

                user_reg = os.path.join(prefix_path, "user.reg")
                self.assertTrue(
                    os.path.isfile(user_reg),
                    f"user.reg missing in prefix for {server_id}: {user_reg}"
                )
                self.assertGreater(
                    os.path.getsize(user_reg),
                    0,
                    f"user.reg is empty in prefix for {server_id}"
                )

    def test_prefix_dxvk_config_injected(self):
        """Verifies that dxvk.conf is properly injected into drive_c of each prefix."""
        for server_id, server in self.servers.items():
            with self.subTest(server=server_id):
                prefix_path = os.path.join(PROJECT_ROOT, server["prefix_dir"])
                dxvk_conf = os.path.join(prefix_path, "drive_c", "dxvk.conf")

                self.assertTrue(
                    os.path.isfile(dxvk_conf),
                    f"dxvk.conf template not injected in drive_c for {server_id}: {dxvk_conf}"
                )
                self.assertGreater(
                    os.path.getsize(dxvk_conf),
                    0,
                    f"dxvk.conf is empty in {dxvk_conf}"
                )

                # Verify dxvk.conf contents has required settings
                with open(dxvk_conf, "r", encoding="utf-8") as f:
                    content = f.read()
                self.assertIn("d3d9.maxFrameRate", content)
                self.assertIn("dxvk.enableAsync", content)


if __name__ == "__main__":
    unittest.main()

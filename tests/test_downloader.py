#!/usr/bin/env python3
"""
Unit and integration tests for L2 Client Acquisition and Staging CLI (scripts/download_clients.sh).
Follows strict TDD Red-Green-Refactor principles and engineering standards.
"""

import json
import os
import subprocess
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOWNLOADER_SCRIPT = os.path.join(PROJECT_ROOT, "scripts", "download_clients.sh")
DOWNLOADS_CONFIG = os.path.join(PROJECT_ROOT, "config", "downloads.json")
SERVERS_CONFIG = os.path.join(PROJECT_ROOT, "config", "servers.json")


class TestClientDownloader(unittest.TestCase):
    def test_01_script_exists_and_executable(self):
        """Verifies scripts/download_clients.sh exists and is executable."""
        self.assertTrue(os.path.isfile(DOWNLOADER_SCRIPT), f"Missing script: {DOWNLOADER_SCRIPT}")
        self.assertTrue(os.access(DOWNLOADER_SCRIPT, os.X_OK), "Script must be executable")

    def test_02_downloads_config_validity_and_parity(self):
        """Ensures config/downloads.json exists, is valid, and matches all servers in servers.json."""
        self.assertTrue(os.path.isfile(DOWNLOADS_CONFIG), f"Missing config: {DOWNLOADS_CONFIG}")
        with open(DOWNLOADS_CONFIG, "r", encoding="utf-8") as f:
            d_data = json.load(f)

        self.assertIn("downloads", d_data)
        downloads = d_data["downloads"]

        with open(SERVERS_CONFIG, "r", encoding="utf-8") as f:
            s_data = json.load(f)
        server_ids = list(s_data.get("servers", {}).keys())

        for s_id in server_ids:
            self.assertIn(s_id, downloads, f"Server {s_id} missing from downloads.json")
            entry = downloads[s_id]
            self.assertIn("client", entry)
            self.assertIn("patch", entry)
            self.assertIn("urls", entry["client"])
            self.assertIsInstance(entry["client"]["urls"], list)
            self.assertGreater(len(entry["client"]["urls"]), 0, f"No URLs defined for {s_id} client")

    def test_03_shared_assets_isolation_policy(self):
        """Verifies that engine-critical packages (system, animations, textures) are NOT shared across chronicles."""
        with open(DOWNLOADS_CONFIG, "r", encoding="utf-8") as f:
            d_data = json.load(f)

        forbidden_shared = {"system", "animations", "textures", "systextures", "staticmeshes", "maps"}
        for s_id, entry in d_data.get("downloads", {}).items():
            shared = set(entry.get("shared_assets", []))
            violation = shared.intersection(forbidden_shared)
            self.assertFalse(
                violation,
                f"Violation of Directiva Suprema: {s_id} attempts to share chronicle-incompatible assets: {violation}"
            )

    def test_04_cli_usage_on_no_args(self):
        """Running with no arguments should display usage and return 1."""
        res = subprocess.run([DOWNLOADER_SCRIPT], capture_output=True, text=True)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("Uso:", res.stdout + res.stderr)

    def test_05_cli_list_command(self):
        """'list' command must report all 3 servers and their download status."""
        res = subprocess.run([DOWNLOADER_SCRIPT, "list"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Failed: {res.stderr}")
        self.assertIn("l2frenzy-interlude", res.stdout)
        self.assertIn("l2scarlet-h5", res.stdout)
        self.assertIn("valhalla-essence", res.stdout)

    def test_06_cli_info_command(self):
        """'info <server_id>' must output detailed target metadata and mirror URLs."""
        res = subprocess.run([DOWNLOADER_SCRIPT, "info", "l2frenzy-interlude"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Failed: {res.stderr}")
        self.assertIn("L2 Frenzy", res.stdout)
        self.assertIn("Interlude", res.stdout)
        self.assertIn("archive.org", res.stdout)

    def test_07_cli_download_dry_run(self):
        """'download <server_id> --dry-run' simulates acquisition without outbound networking."""
        res = subprocess.run([DOWNLOADER_SCRIPT, "download", "l2scarlet-h5", "--dry-run"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Dry-run failed: {res.stderr}")
        self.assertIn("[DRY-RUN]", res.stdout)
        self.assertIn("Lineage_II_HighFive.7z", res.stdout)

    def test_08_cli_extract_dry_run(self):
        """'extract <server_id> --dry-run' simulates staging and directory layout normalization."""
        res = subprocess.run([DOWNLOADER_SCRIPT, "extract", "valhalla-essence", "--dry-run"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Extract dry-run failed: {res.stderr}")
        self.assertIn("[DRY-RUN]", res.stdout)
        self.assertIn("valhalla-essence", res.stdout)

    def test_09_cli_unknown_server_fails(self):
        """Passing an unrecognized server ID should fail with exit code 1."""
        res = subprocess.run([DOWNLOADER_SCRIPT, "info", "unknown-server-xyz"], capture_output=True, text=True)
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("No se encontró configuración", res.stderr + res.stdout)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""
Unit and integration tests for the 1-Click Setup & Optimization Tool (quick_setup.sh).
Follows strict TDD and Engineering Directives: Cero complacencia, Cero sesgo, Cero espejo.
"""

import os
import subprocess
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
QUICK_SETUP_SH = os.path.join(PROJECT_ROOT, "quick_setup.sh")
SETUP_SH_SYMLINK = os.path.join(PROJECT_ROOT, "setup.sh")
SETUP_DXVK_SH = os.path.join(PROJECT_ROOT, "scripts", "setup_dxvk.sh")
INSTALL_DESKTOP = os.path.join(PROJECT_ROOT, "Instalar-L2-Sudamerica.desktop")


class TestQuickSetup(unittest.TestCase):
    def test_scripts_exist_and_executable(self):
        """Verifies quick_setup.sh and setup_dxvk.sh exist and are executable."""
        self.assertTrue(os.path.isfile(QUICK_SETUP_SH), "quick_setup.sh missing")
        self.assertTrue(os.access(QUICK_SETUP_SH, os.X_OK), "quick_setup.sh not executable")

        self.assertTrue(os.path.isfile(SETUP_DXVK_SH), "scripts/setup_dxvk.sh missing")
        self.assertTrue(os.access(SETUP_DXVK_SH, os.X_OK), "scripts/setup_dxvk.sh not executable")

        self.assertTrue(os.path.exists(SETUP_SH_SYMLINK), "setup.sh shortcut missing")

    def test_bash_syntax_validity(self):
        """Validates bash syntax via bash -n."""
        for path in [QUICK_SETUP_SH, SETUP_DXVK_SH]:
            if os.path.isfile(path):
                res = subprocess.run(["bash", "-n", path], capture_output=True, text=True)
                self.assertEqual(res.returncode, 0, f"Syntax error in {path}: {res.stderr}")

    def test_help_flag_displays_usage(self):
        """quick_setup.sh --help must return 0 and display usage options."""
        res = subprocess.run([QUICK_SETUP_SH, "--help"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Failed --help: {res.stderr}")
        self.assertIn("Lineage 2 Sudamérica", res.stdout)
        self.assertIn("--dry-run", res.stdout)
        self.assertIn("--client-path", res.stdout)

    def test_dry_run_executes_safely(self):
        """quick_setup.sh --dry-run must inspect environment and exit cleanly with 0."""
        res = subprocess.run([QUICK_SETUP_SH, "--dry-run"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Dry-run failed: {res.stderr}")
        self.assertIn("DRY-RUN", res.stdout)

    def test_desktop_installer_shortcut_validity(self):
        """Instalar-L2-Sudamerica.desktop must exist and contain valid desktop entry keys."""
        self.assertTrue(os.path.isfile(INSTALL_DESKTOP), "Desktop installer launcher missing")
        with open(INSTALL_DESKTOP, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("[Desktop Entry]", content)
        self.assertIn("Type=Application", content)
        self.assertIn("Terminal=true", content)
        self.assertIn("quick_setup.sh", content)

    def test_git_tracked_hygiene_no_large_binaries_or_secrets(self):
        """Ensures git never tracks game clients, large archives or credentials."""
        res = subprocess.run(["git", "ls-files"], cwd=PROJECT_ROOT, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"git ls-files failed: {res.stderr}")
        files = res.stdout.splitlines()

        forbidden_extensions = (".zip", ".rar", ".7z", ".iso", ".tar.gz", ".tar.xz")
        for f in files:
            self.assertFalse(f.endswith(forbidden_extensions), f"Forbidden archive tracked in git: {f}")
            self.assertFalse(f.startswith("clients/") and not f.endswith(".gitkeep"), f"Client file tracked: {f}")
            self.assertFalse(f.startswith("prefixes/") and not f.endswith(".gitkeep"), f"Prefix file tracked: {f}")
            self.assertFalse(f == ".env" or f.endswith(".local") or f.endswith(".local.json"), f"Secret file tracked: {f}")


if __name__ == "__main__":
    unittest.main()

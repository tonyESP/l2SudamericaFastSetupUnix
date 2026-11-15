#!/usr/bin/env python3
"""
Integration and CLI behavior tests for l2_ctl orchestrator.
"""

import os
import subprocess
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
L2_CTL = os.path.join(PROJECT_ROOT, "scripts", "l2_ctl.sh")


class TestL2CtlOrchestrator(unittest.TestCase):
    def test_l2_ctl_executable(self):
        self.assertTrue(os.path.isfile(L2_CTL))
        self.assertTrue(os.access(L2_CTL, os.X_OK), "scripts/l2_ctl.sh must be executable")

    def test_doctor_command_success(self):
        res = subprocess.run([L2_CTL, "doctor"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Doctor failed: {res.stderr}")
        self.assertIn("DIAGNÓSTICO DE INGENIERÍA DEL SISTEMA", res.stdout)
        self.assertIn("GPU NVIDIA", res.stdout)
        self.assertIn("Vulkan 1.3", res.stdout)

    def test_list_command_success(self):
        res = subprocess.run([L2_CTL, "list"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"List failed: {res.stderr}")
        self.assertIn("l2sudamerica-interlude", res.stdout)
        self.assertIn("l2sudamerica-optimized", res.stdout)
        self.assertNotIn("l2frenzy-interlude", res.stdout)

    def test_download_command_delegation(self):
        res = subprocess.run([L2_CTL, "download", "list"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Download delegation failed: {res.stderr}")
        self.assertIn("CATÁLOGO DE ADQUISICIÓN Y STAGING DE CLIENTES L2", res.stdout)

    def test_invalid_command_shows_usage(self):
        res = subprocess.run([L2_CTL, "invalid_cmd"], capture_output=True, text=True)
        self.assertIn("Uso:", res.stdout)


if __name__ == "__main__":
    unittest.main()

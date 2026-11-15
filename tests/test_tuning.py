#!/usr/bin/env python3
"""
Unit tests for L2 tuning configuration templates (dxvk.conf.template, Option.ini.template).
"""

import os
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DXVK_TEMPLATE = os.path.join(PROJECT_ROOT, "config", "dxvk.conf.template")
OPTION_TEMPLATE = os.path.join(PROJECT_ROOT, "config", "Option.ini.template")


class TestTuningTemplates(unittest.TestCase):
    def test_dxvk_template_exists_and_valid(self):
        self.assertTrue(os.path.isfile(DXVK_TEMPLATE))
        with open(DXVK_TEMPLATE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check required DXVK directives for Unreal Engine 2.5 on NVIDIA Turing
        self.assertIn("d3d9.maxFrameRate", content)
        self.assertIn("d3d9.samplerAnisotropy", content)
        self.assertIn("d3d9.deferSurfaceCreation", content)
        self.assertIn("dxvk.enableAsync", content)

    def test_option_ini_template_exists_and_valid(self):
        self.assertTrue(os.path.isfile(OPTION_TEMPLATE))
        with open(OPTION_TEMPLATE, "r", encoding="utf-8") as f:
            content = f.read()

        # Check critical video sections
        self.assertIn("[Video]", content)
        self.assertIn("StartupResolutionX=1920", content)
        self.assertIn("StartupResolutionY=1080", content)
        self.assertIn("ColorBits=32", content)


if __name__ == "__main__":
    unittest.main()

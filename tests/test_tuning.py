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

    def test_desktop_launchers_and_icon_exist(self):
        icon_path = os.path.join(PROJECT_ROOT, "config", "l2-icon.png")
        self.assertTrue(os.path.isfile(icon_path), f"Missing L2 icon: {icon_path}")
        self.assertGreater(os.path.getsize(icon_path), 500, "L2 icon appears empty")

        for profile in ("l2suda-optimizado", "l2suda-asedio"):
            desktop_path = os.path.join(PROJECT_ROOT, "config", f"{profile}.desktop")
            self.assertTrue(os.path.isfile(desktop_path), f"Missing desktop entry: {desktop_path}")
            with open(desktop_path, "r", encoding="utf-8") as f:
                d_content = f.read()
            self.assertIn(f"Name={profile}\n", d_content)
            self.assertIn(f"Exec=/mnt/disk4u/L2/scripts/l2_ctl.sh run {profile}", d_content)
            self.assertIn(f"Icon={icon_path}", d_content)

    def test_reproducible_profile_templates_exist(self):
        checks = {
            "vkBasalt.conf.template": [
                "effects = smaa:tonemap:vibrance:curves:cas",
                "casSharpness = 0.45",
            ],
            "dxvk.siege.conf.template": [
                "d3d9.samplerAnisotropy = 4",
            ],
            "Option.optimized.ini.template": [
                "Pawn=6.000000",
                "PostProc=0",
            ],
            "Option.siege.ini.template": [
                "PawnShadow=False",
                "SkipAnim=1",
            ],
        }
        for filename, snippets in checks.items():
            path = os.path.join(PROJECT_ROOT, "config", filename)
            self.assertTrue(os.path.isfile(path), f"Missing template: {path}")
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            for s in snippets:
                self.assertIn(s, content, f"Missing '{s}' in {filename}")

    def test_portability_and_active_dxvk_directives(self):
        env_path = os.path.join(PROJECT_ROOT, "scripts", "env.sh")
        with open(env_path, "r", encoding="utf-8") as f:
            env_content = f.read()
        self.assertNotIn('L2_PROJECT_ROOT="/mnt/disk4u/L2"', env_content)
        self.assertNotIn("/home/floky", env_content)

        apply_path = os.path.join(PROJECT_ROOT, "scripts", "apply_tuning.sh")
        with open(apply_path, "r", encoding="utf-8") as f:
            apply_content = f.read()
        self.assertIn("--force", apply_content)

        for tmpl in ("dxvk.conf.template", "dxvk.siege.conf.template"):
            with open(os.path.join(PROJECT_ROOT, "config", tmpl), "r", encoding="utf-8") as f:
                lines = [ln.strip() for ln in f if ln.strip() and not ln.lstrip().startswith("#")]
            self.assertIn("dxvk.enableGraphicsPipelineLibrary = Auto", lines)
            self.assertIn("dxvk.numCompilerThreads = 4", lines)


if __name__ == "__main__":
    unittest.main()

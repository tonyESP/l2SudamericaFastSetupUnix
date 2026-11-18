import os
import subprocess
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


class TestRelayRouting(unittest.TestCase):
    def test_relay_scripts_exist_and_executable(self):
        relay_ctl = os.path.join(PROJECT_ROOT, "scripts", "relay_ctl.sh")
        setup_vps = os.path.join(PROJECT_ROOT, "tools", "relay", "setup_vps.sh")

        self.assertTrue(os.path.isfile(relay_ctl), f"{relay_ctl} missing")
        self.assertTrue(os.access(relay_ctl, os.X_OK), f"{relay_ctl} not executable")

        self.assertTrue(os.path.isfile(setup_vps), f"{setup_vps} missing")
        self.assertTrue(os.access(setup_vps, os.X_OK), f"{setup_vps} not executable")

    def test_bash_syntax_validity(self):
        scripts = [
            os.path.join(PROJECT_ROOT, "scripts", "relay_ctl.sh"),
            os.path.join(PROJECT_ROOT, "tools", "relay", "setup_vps.sh"),
        ]
        for script in scripts:
            res = subprocess.run(["bash", "-n", script], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, f"Syntax error in {script}: {res.stderr}")

    def test_wireguard_template_strict_split_tunnel(self):
        template_file = os.path.join(PROJECT_ROOT, "config", "relay", "wg-l2suda.conf.template")
        self.assertTrue(os.path.isfile(template_file), f"{template_file} missing")

        with open(template_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Enforce that AllowedIPs ONLY targets the L2 game server and tunnel peer, not 0.0.0.0/0
        self.assertIn("AllowedIPs", content)
        self.assertIn("45.235.99.29/32", content)
        self.assertNotIn("0.0.0.0/0", content, "Security violation: Relay must NOT be full tunnel")

    def test_relay_ctl_doctor_command(self):
        relay_ctl = os.path.join(PROJECT_ROOT, "scripts", "relay_ctl.sh")
        res = subprocess.run([relay_ctl, "doctor"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("iproute2", res.stdout)


if __name__ == "__main__":
    unittest.main()

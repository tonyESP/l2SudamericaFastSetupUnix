#!/usr/bin/env python3
"""
Unit tests for L2 server configuration catalog (config/servers.json).
Follows TDD and strict data integrity standards.
"""

import json
import os
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CONFIG_FILE = os.path.join(PROJECT_ROOT, "config", "servers.json")


class TestServersConfig(unittest.TestCase):
    def setUp(self):
        self.assertTrue(os.path.isfile(CONFIG_FILE), f"Missing config file: {CONFIG_FILE}")
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            self.data = json.load(f)

    def test_version_present(self):
        self.assertIn("version", self.data)
        self.assertIsInstance(self.data["version"], str)

    def test_servers_exist(self):
        self.assertIn("servers", self.data)
        self.assertGreater(len(self.data["servers"]), 0, "No servers declared in configuration")

    def test_mandatory_fields_per_server(self):
        mandatory_fields = [
            "id", "name", "chronicle", "rates", "style",
            "website", "anticheat", "linux_status", "client_dir",
            "prefix_dir", "executable", "winetricks"
        ]
        for server_id, server in self.data["servers"].items():
            self.assertEqual(server_id, server.get("id"), f"Mismatch key/id for {server_id}")
            for field in mandatory_fields:
                self.assertIn(field, server, f"Server {server_id} is missing mandatory field: {field}")
            
            # Validate rates dictionary
            rates = server["rates"]
            self.assertIn("exp", rates, f"Server {server_id} missing exp rate")
            self.assertIn("sp", rates, f"Server {server_id} missing sp rate")
            self.assertIn("adena", rates, f"Server {server_id} missing adena rate")

    def test_path_hygiene(self):
        for server_id, server in self.data["servers"].items():
            client_dir = server["client_dir"]
            prefix_dir = server["prefix_dir"]
            self.assertTrue(client_dir.startswith("clients/"), f"Invalid client_dir prefix in {server_id}")
            self.assertTrue(prefix_dir.startswith("prefixes/"), f"Invalid prefix_dir prefix in {server_id}")
            self.assertFalse(client_dir.endswith("/"), f"client_dir should not have trailing slash in {server_id}")
            self.assertFalse(prefix_dir.endswith("/"), f"prefix_dir should not have trailing slash in {server_id}")


if __name__ == "__main__":
    unittest.main()

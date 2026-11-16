#!/usr/bin/env python3
"""
Unit tests for L2 Auth TCP relay proxy and shim integration.
Follows TDD: written before implementing scripts/l2_auth_proxy.py.
"""

import json
import os
import socket
import subprocess
import sys
import threading
import time
import unittest

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PROXY_SCRIPT = os.path.join(PROJECT_ROOT, "scripts", "l2_auth_proxy.py")
SHIM_SO = os.path.join(PROJECT_ROOT, "tools", "shims", "l2_auth_redir.so")
CONFIG_FILE = os.path.join(PROJECT_ROOT, "config", "servers.json")


class TestAuthProxy(unittest.TestCase):
    def test_shim_binary_exists(self):
        self.assertTrue(os.path.isfile(SHIM_SO), f"Missing compiled shim: {SHIM_SO}")

    def test_servers_json_declares_auth_proxy_and_runner(self):
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        srv = data["servers"]["l2sudamerica-interlude"]
        self.assertEqual(srv.get("runner"), "wine-11.22-staging-amd64")
        proxy = srv.get("auth_proxy")
        self.assertIsInstance(proxy, dict)
        self.assertEqual(proxy.get("host"), "l2.lineage2sudamerica.com")
        self.assertEqual(proxy.get("port"), 2106)

    def test_bidirectional_tcp_relay(self):
        self.assertTrue(os.path.isfile(PROXY_SCRIPT), f"Missing proxy script: {PROXY_SCRIPT}")
        sys.path.insert(0, os.path.join(PROJECT_ROOT, "scripts"))
        import l2_auth_proxy

        cli_end, proxy_cli_end = socket.socketpair()
        proxy_rem_end, rem_end = socket.socketpair()

        relay_thread = threading.Thread(
            target=l2_auth_proxy._relay_pair,
            args=(proxy_cli_end, proxy_rem_end),
            daemon=True,
        )
        relay_thread.start()

        try:
            rem_end.sendall(b"\xba\x00INIT_OK")
            self.assertEqual(cli_end.recv(1024), b"\xba\x00INIT_OK")
            cli_end.sendall(b"LOGIN_REQ")
            self.assertEqual(rem_end.recv(1024), b"LOGIN_REQ")
        finally:
            cli_end.close()
            rem_end.close()
            relay_thread.join(timeout=2.0)

    def test_tune_tcp_socket_sets_low_latency_flags(self):
        sys.path.insert(0, os.path.join(PROJECT_ROOT, "scripts"))
        import l2_auth_proxy

        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            l2_auth_proxy._tune_tcp_socket(s)
            self.assertEqual(s.getsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY), 1)
            self.assertEqual(s.getsockopt(socket.IPPROTO_IP, socket.IP_TOS) & 0xFC, 0xB8 & 0xFC)
        finally:
            s.close()


if __name__ == "__main__":
    unittest.main()

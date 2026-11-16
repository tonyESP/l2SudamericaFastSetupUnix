#!/usr/bin/env python3
"""
Local TCP relay for Lineage 2 AuthServer connections under Wine.

Wine's WSAAsyncSelect can miss FD_CONNECT/FD_READ transitions when an external
AuthServer has high TCP SYN-ACK latency (e.g., anti-DDoS SYN-proxy > 50ms) and
the client overwrites the event mask before the handshake completes. Relaying
through 127.0.0.1 lets Wine complete the local TCP handshake immediately while
forwarding raw packets transparently to the remote AuthServer.
"""

import argparse
import select
import signal
import socket
import sys
import threading
from types import FrameType
from typing import Optional


_TCP_THIN_LINEAR_TIMEOUTS = 16
_TCP_THIN_DUPACK = 17
_DSCP_EF_TOS = 0xB8


def _tune_tcp_socket(sock: socket.socket) -> None:
    """Apply per-socket low-latency TCP and Wi-Fi WMM QoS flags."""
    if sock.family != socket.AF_INET:
        return
    try:
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    except OSError:
        pass
    quickack = getattr(socket, "TCP_QUICKACK", 12)
    for opt in (quickack, _TCP_THIN_LINEAR_TIMEOUTS, _TCP_THIN_DUPACK):
        try:
            sock.setsockopt(socket.IPPROTO_TCP, opt, 1)
        except OSError:
            pass
    try:
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_TOS, _DSCP_EF_TOS)
    except OSError:
        pass


def _relay_pair(client_sock: socket.socket, remote_sock: socket.socket) -> None:
    """Forward bytes bidirectionally until either peer closes or errors."""
    sockets = [client_sock, remote_sock]
    quickack = getattr(socket, "TCP_QUICKACK", 12)
    try:
        while True:
            readable, _, _ = select.select(sockets, [], [], 60.0)
            if not readable:
                continue
            for src in readable:
                dst = remote_sock if src is client_sock else client_sock
                try:
                    data = src.recv(8192)
                except OSError:
                    return
                if src.family == socket.AF_INET:
                    try:
                        src.setsockopt(socket.IPPROTO_TCP, quickack, 1)
                    except OSError:
                        pass
                if not data:
                    return
                try:
                    dst.sendall(data)
                except OSError:
                    return
    finally:
        client_sock.close()
        remote_sock.close()


def _handle_client(
    client_sock: socket.socket,
    target_host: str,
    target_port: int,
    connect_timeout: float,
) -> None:
    """Connect to the upstream AuthServer and relay traffic for one client."""
    _tune_tcp_socket(client_sock)
    try:
        remote_sock = socket.create_connection(
            (target_host, target_port), timeout=connect_timeout
        )
        remote_sock.settimeout(None)
        _tune_tcp_socket(remote_sock)
    except OSError:
        client_sock.close()
        return

    _relay_pair(client_sock, remote_sock)


def run_proxy(
    listen_host: str,
    listen_port: int,
    target_host: str,
    target_port: int,
    connect_timeout: float = 10.0,
) -> None:
    """Bind the local TCP listener and spawn a relay thread per connection."""
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind((listen_host, listen_port))
    server_sock.listen(16)
    server_sock.settimeout(1.0)

    stop_event = threading.Event()

    def _handle_signal(_signum: int, _frame: Optional[FrameType]) -> None:
        stop_event.set()

    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    try:
        while not stop_event.is_set():
            try:
                client_sock, _ = server_sock.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            worker = threading.Thread(
                target=_handle_client,
                args=(client_sock, target_host, target_port, connect_timeout),
                daemon=True,
            )
            worker.start()
    finally:
        server_sock.close()


def main(argv: Optional[list[str]] = None) -> int:
    """CLI entrypoint."""
    parser = argparse.ArgumentParser(description="Local TCP AuthServer relay for Wine")
    parser.add_argument("--listen-host", default="127.0.0.1")
    parser.add_argument("--listen-port", type=int, default=21060)
    parser.add_argument("--target-host", required=True)
    parser.add_argument("--target-port", type=int, default=2106)
    parser.add_argument("--connect-timeout", type=float, default=10.0)
    args = parser.parse_args(argv)

    run_proxy(
        listen_host=args.listen_host,
        listen_port=args.listen_port,
        target_host=args.target_host,
        target_port=args.target_port,
        connect_timeout=args.connect_timeout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

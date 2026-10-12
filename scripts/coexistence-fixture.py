#!/usr/bin/env python3
"""Real Herdr fixture. All state and the named session belong to this test."""
import base64
import json
import os
from pathlib import Path
import queue
import socket
import subprocess
import sys
import tempfile
import threading
import time


def main():
    binary = str(Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix="hx-coexist-", dir="/tmp") as temp:
        root = Path(temp)
        env = os.environ.copy()
        for key in ("HERDR_SOCKET_PATH", "HERDR_CLIENT_SOCKET_PATH", "HERDR_SESSION", "HERDR_SESSION_NAME", "HERDR_PANE_ID", "HERDR_TERMINAL_ID"):
            env.pop(key, None)
        env.update(XDG_CONFIG_HOME=temp + "/c", XDG_STATE_HOME=temp + "/s", HERDR_CONFIG_PATH=temp + "/c/herdr/config.toml", HERDRX_STATE_DIR=temp + "/x", SHELL="/bin/sh")
        bindir = root / "bin"
        bindir.mkdir()
        (bindir / "herdr").symlink_to(binary)
        env["PATH"] = str(bindir) + os.pathsep + env.get("PATH", "")
        config = root / "c/herdr/config.toml"
        config.parent.mkdir(parents=True)
        config.write_text('[terminal]\ndefault_shell = "/bin/sh"\nshell_mode = "non_login"\n')
        path = root / "c/herdr/sessions/coexist/herdr.sock"
        def rpc(method, params=None):
            with socket.socket(socket.AF_UNIX) as sock:
                sock.settimeout(3)
                sock.connect(str(path))
                sock.sendall((json.dumps(dict(id="test", method=method, params=params or {})) + "\n").encode())
                with sock.makefile("rb") as stream:
                    result = json.loads(stream.readline())
                assert "error" not in result or result["error"] is None, result
                return result["result"]
        processes = []
        def stream(*args):
            process = subprocess.Popen([binary, *args], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
            processes.append(process)
            lines = queue.Queue()
            def drain():
                for line in process.stdout:
                    lines.put(json.loads(line))
            threading.Thread(target=drain, daemon=True).start()
            return process, lines
        with (root / "server.log").open("wb") as log:
            server = subprocess.Popen([binary, "--session", "coexist", "server"], env=env, stdout=log, stderr=log)
            try:
                for _ in range(100):
                    if path.exists():
                        try:
                            rpc("session.snapshot")
                            break
                        except (OSError, ValueError):
                            pass
                    if server.poll() is not None:
                        raise RuntimeError((root / "server.log").read_text())
                    time.sleep(.05)
                created = rpc("workspace.create", dict(cwd=temp, label="Isolated coexistence test", focus=False))
                snapshot = rpc("session.snapshot")["snapshot"]
                # macOS canonicalizes /tmp to /private/tmp; use server identity.
                pane = next(p for p in snapshot["panes"] if p["workspace_id"] == created["workspace"]["workspace_id"])
                env["HERDR_SOCKET_PATH"] = str(path)
                if len(sys.argv) > 2:
                    subprocess.run([str(Path(sys.argv[2]).resolve()), str(path), pane["terminal_id"], pane["pane_id"], temp], env=env, check=True, timeout=60)
                else:
                    before = rpc("pane.process_info", dict(pane_id=pane["pane_id"]))["process_info"]
                    owner, frames = stream("terminal", "session", "control", pane["terminal_id"], "--cols", "97", "--rows", "31")
                    assert frames.get(timeout=5)["type"] == "terminal.frame"
                    rejected, rejected_frames = stream("terminal", "session", "control", pane["terminal_id"])
                    closed = rejected_frames.get(timeout=5)
                    assert closed["type"] == "terminal.closed" and "already has an attached client" in closed["reason"], closed
                    assert owner.poll() is None
                    observer, observed = stream("terminal", "session", "observe", pane["terminal_id"], "--cols", "120", "--rows", "40")
                    assert observed.get(timeout=5)["full"] is True
                    owner.stdin.write((json.dumps(dict(type="terminal.input", text="printf 'LIVE_OBSERVER\\n'\n")) + "\n").encode())
                    owner.stdin.flush()
                    output = b""
                    deadline = time.monotonic() + 5
                    while b"LIVE_OBSERVER" not in output and time.monotonic() < deadline:
                        frame = observed.get(timeout=5)
                        output += base64.b64decode(frame["bytes"])
                    assert b"LIVE_OBSERVER" in output
                    observer.terminate(); observer.wait(timeout=5)
                    assert owner.poll() is None
                    taker, taken = stream("terminal", "session", "control", pane["terminal_id"], "--takeover")
                    assert taken.get(timeout=5)["type"] == "terminal.frame"
                    owner.wait(timeout=5)
                    after = rpc("pane.process_info", dict(pane_id=pane["pane_id"]))["process_info"]
                    assert before["shell_pid"] == after["shell_pid"]
                    print("PASS: Herdr 0.9.3 normal attach refusal, observer live output, observer detach preserves owner, explicit takeover preserves shell PID")
            finally:
                for process in processes:
                    if process.poll() is None:
                        process.terminate()
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill(); process.wait()
                subprocess.run([binary, "--session", "coexist", "server", "stop"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.terminate(); server.wait(timeout=5)


if __name__ == "__main__":
    main()

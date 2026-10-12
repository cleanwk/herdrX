#!/usr/bin/env python3
"""Capture authoritative layouts from isolated old/new Herdr servers."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile


def capture(binary, nonzero):
    binary = str(Path(binary).resolve())
    with tempfile.TemporaryDirectory(prefix="hx-layout-", dir="/tmp") as temporary:
        env = {key: value for key, value in os.environ.items() if not key.startswith("HERDR_")}
        env.update(XDG_CONFIG_HOME=temporary + "/c", XDG_STATE_HOME=temporary + "/s",
                   HERDRX_STATE_DIR=temporary + "/x", SHELL="/bin/sh")
        config = Path(temporary) / "c/herdr/config.toml"
        config.parent.mkdir(parents=True)
        config.write_text('[terminal]\ndefault_shell = "/bin/sh"\nshell_mode = "non_login"\n')
        args = [binary, "--session", "layout-fixture"]

        def cli(*tail):
            return subprocess.run(args + list(tail), env=env, stdin=subprocess.DEVNULL,
                                  capture_output=True, check=True, timeout=15).stdout

        try:
            cli("remote-client-bridge")
            status = json.loads(cli("status", "server", "--json"))
            path = status["socket"]
            assert Path(path).resolve().is_relative_to(Path(temporary).resolve())

            def rpc(method, params=None):
                with socket.socket(socket.AF_UNIX) as connection:
                    connection.settimeout(5)
                    connection.connect(path)
                    connection.sendall((json.dumps(dict(id="layout", method=method, params=params or {})) + "\n").encode())
                    with connection.makefile("rb") as stream:
                        response = json.loads(stream.readline())
                    assert not response.get("error"), response
                    return response["result"]

            workspace = rpc("workspace.create", dict(cwd=temporary, label="Layout fixture", focus=True))["workspace"]["workspace_id"]
            snapshot = rpc("session.snapshot")["snapshot"]
            original = next(pane for pane in snapshot["panes"] if pane["workspace_id"] == workspace)
            tab = original["tab_id"]
            cases = []

            def record(name, count):
                snapshot = rpc("session.snapshot")["snapshot"]
                layout = next(layout for layout in snapshot["layouts"] if layout["tab_id"] == tab)
                assert len(layout["panes"]) == count
                area = layout["area"]
                assert bool(area["x"] or area["y"]) == nonzero, area
                cases.append(dict(name=name, server_version=snapshot["version"], layout=layout))

            record("single", 1)
            rpc("pane.split", dict(pane_id=original["pane_id"], direction="right"))
            record("columns", 2)
            rpc("pane.split", dict(pane_id=original["pane_id"], direction="down"))
            record("nested", 3)
            remaining = rpc("session.snapshot")["snapshot"]["panes"]
            assert any(pane["pane_id"] == original["pane_id"] and pane["terminal_id"] == original["terminal_id"] for pane in remaining)
            return cases
        finally:
            subprocess.run(args + ["server", "stop"], env=env, capture_output=True, timeout=10)


if __name__ == "__main__":
    legacy, current, output = sys.argv[1:]
    cases = capture(legacy, nonzero=True) + capture(current, nonzero=False)
    Path(output).write_text(json.dumps(cases, indent=2) + "\n")
    for case in cases:
        print(f"PASS: Herdr {case['server_version']} {case['name']}: area={case['layout']['area']}")

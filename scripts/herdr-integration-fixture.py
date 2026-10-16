#!/usr/bin/env python3
"""Supported bootstrap/plugin contracts against an isolated real Herdr server."""
import json
import os
from pathlib import Path
import socket
import selectors
import subprocess
import sys
import tempfile
import time


def main():
    binary = str(Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix="hx-integration-", dir="/tmp") as temp:
        root = Path(temp)
        env = {k: v for k, v in os.environ.items() if not k.startswith("HERDR_")}
        env.update(XDG_CONFIG_HOME=temp + "/c", XDG_STATE_HOME=temp + "/s", HERDRX_STATE_DIR=temp + "/x", SHELL="/bin/sh")
        args = [binary, "--session", "integration"]
        def cli(*tail):
            result = subprocess.run(args + list(tail), env=env, stdin=subprocess.DEVNULL, capture_output=True, timeout=15)
            assert result.returncode == 0, (tail, result.stdout.decode(), result.stderr.decode())
            return result.stdout
        plugin = root / "plugin"
        plugin.mkdir()
        (plugin / "herdr-plugin.toml").write_text('''id = "herdrx.fixture"
name = "HerdrX integration fixture"
version = "0.1.0"
min_herdr_version = "0.9.3"
[[actions]]
id = "status"
title = "Fixture action"
contexts = ["global"]
command = ["/bin/sh", "-c", "printf 'ACTION_OK'"]
[[panes]]
id = "board"
title = "Fixture pane"
command = ["/bin/sh", "-c", "printf 'PLUGIN_OK'; exec sleep 60"]
''')
        try:
            before = json.loads(cli("status", "server", "--json"))
            assert before["running"] is False
            cli("remote-client-bridge")
            after = json.loads(cli("status", "server", "--json"))
            assert after["running"] and Path(after["socket"]).resolve().is_relative_to(root.resolve())
            path = after["socket"]
            def rpc(method, params=None):
                with socket.socket(socket.AF_UNIX) as connection:
                    connection.settimeout(5)
                    connection.connect(path)
                    connection.sendall((json.dumps(dict(id="fixture", method=method, params=params or {})) + "\n").encode())
                    with connection.makefile("rb") as stream:
                        value = json.loads(stream.readline())
                    assert value.get("error") is None, value
                    return value["result"]
            # Only our disposable manifest is installed; no user plugin state.
            cli("plugin", "link", str(plugin))
            listed = rpc("plugin.list")["plugins"]
            assert any(p["plugin_id"] == "herdrx.fixture" for p in listed)
            workspace = rpc("workspace.create", dict(cwd=temp, label="Integration", focus=False))["workspace"]["workspace_id"]
            snapshot = rpc("session.snapshot")["snapshot"]
            original = next(p for p in snapshot["panes"] if p["workspace_id"] == workspace)
            # Verify scoped-read field/target contracts against real Herdr 0.9.3.
            # This metadata belongs only to the explicitly named disposable fixture.
            rpc("pane.report_agent", dict(pane_id=original["pane_id"], source="herdrx.synthetic.fixture", agent="codex", state="working"))
            assert rpc("ping")["version"]
            before_spaces = rpc("workspace.list")["workspaces"]
            all_panes = []
            for space in before_spaces:
                params = dict(workspace_id=space["workspace_id"])
                tabs = rpc("tab.list", params)["tabs"]
                panes = rpc("pane.list", params)["panes"]
                all_panes.extend(panes)
                assert len(tabs) == space["tab_count"] and len(panes) == space["pane_count"]
                for tab in tabs:
                    members = [p for p in panes if p["tab_id"] == tab["tab_id"]]
                    assert len(members) == tab["pane_count"]
                    layout = rpc("pane.layout", dict(pane_id=members[0]["pane_id"]))["layout"]
                    assert layout["workspace_id"] == space["workspace_id"] and layout["tab_id"] == tab["tab_id"]
                    assert {p["pane_id"] for p in layout["panes"]} == {p["pane_id"] for p in members}
            current = rpc("pane.current")["pane"]
            assert any(all(p[k] == current[k] for k in ("workspace_id", "tab_id", "pane_id", "terminal_id")) for p in all_panes)
            agents = rpc("agent.list")["agents"]
            assert any(a["pane_id"] == original["pane_id"] for a in agents)
            for agent in agents:
                fetched_agent = rpc("agent.get", dict(target=agent["pane_id"]))["agent"]
                assert all(fetched_agent[k] == agent[k] for k in ("workspace_id", "tab_id", "pane_id", "terminal_id"))
            topology = lambda spaces: {s["workspace_id"]: (s["tab_count"], s["pane_count"]) for s in spaces}
            assert topology(before_spaces) == topology(rpc("workspace.list")["workspaces"])
            print("PASS: real Herdr scoped workspace/tab/pane/layout/current/agent read contracts")
            rpc("plugin.action.invoke", dict(plugin_id="herdrx.fixture", action_id="status", context=dict(invocation_source="gui")))
            pane = rpc("plugin.pane.open", dict(plugin_id="herdrx.fixture", entrypoint="board", placement="tab", focus=False, workspace_id=workspace))["plugin_pane"]["pane"]
            fetched = rpc("pane.get", dict(pane_id=pane["pane_id"]))["pane"]
            assert fetched["terminal_id"] == pane["terminal_id"]
            observer_env = dict(env, HERDR_SOCKET_PATH=path)
            observer = subprocess.Popen([binary, "terminal", "session", "observe", pane["terminal_id"]], env=observer_env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                with selectors.DefaultSelector() as selector:
                    selector.register(observer.stdout, selectors.EVENT_READ)
                    assert selector.select(timeout=5), "No plugin terminal frame"
                frame = json.loads(observer.stdout.readline())
                assert frame["type"] == "terminal.frame", frame
            finally:
                observer.terminate(); observer.wait(timeout=5)
            rpc("plugin.pane.close", dict(pane_id=pane["pane_id"]))
            remaining = rpc("session.snapshot")["snapshot"]["panes"]
            assert any(p["pane_id"] == original["pane_id"] and p["terminal_id"] == original["terminal_id"] for p in remaining)
            assert not any(p["pane_id"] == pane["pane_id"] for p in remaining)
            print("PASS: stopped named server bootstrap, socket resolution, plugin discovery/action, attachable pane and targeted close preserve original terminal")
        finally:
            subprocess.run(args + ["server", "stop"], env=env, capture_output=True, timeout=10)


if __name__ == "__main__":
    main()

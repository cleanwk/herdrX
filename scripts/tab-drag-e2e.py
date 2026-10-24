#!/usr/bin/env python3
"""Drag a tab in the built HerdrX.app against a real Herdr server, via HID events."""
import json, os, socket, subprocess, sys, tempfile, time
from pathlib import Path

herdr, app, driver = (str(Path(a).resolve()) for a in sys.argv[1:4])
out = Path("build/tests"); out.mkdir(parents=True, exist_ok=True)
temp = tempfile.mkdtemp(prefix="hx-drag-", dir="/tmp")
env = {k: v for k, v in os.environ.items() if not k.startswith("HERDR_")}
env.update(XDG_CONFIG_HOME=temp + "/c", XDG_STATE_HOME=temp + "/s", HERDRX_STATE_DIR=temp + "/x", SHELL="/bin/sh", HERDRX_TRACE_TAB_DRAG="1")
args = [herdr, "--session", "dragtest"]
def cli(*tail):
    r = subprocess.run(args + list(tail), env=env, stdin=subprocess.DEVNULL, capture_output=True, timeout=20)
    assert r.returncode == 0, (tail, r.stdout, r.stderr); return r.stdout
cli("remote-client-bridge")
path = json.loads(cli("status", "server", "--json"))["socket"]
def rpc(method, params=None):
    with socket.socket(socket.AF_UNIX) as c:
        c.settimeout(5); c.connect(path)
        c.sendall((json.dumps(dict(id="t", method=method, params=params or {})) + "\n").encode())
        with c.makefile("rb") as s: v = json.loads(s.readline())
    assert v.get("error") is None, v; return v["result"]
ws = rpc("workspace.create", dict(cwd=temp, label="DragSpace", focus=True))["workspace"]["workspace_id"]
for _ in range(2): rpc("tab.create", dict(workspace_id=ws, cwd=temp, focus=False))
tabs = rpc("tab.list", dict(workspace_id=ws))["tabs"]
for tab, name in zip(tabs, ["T-A", "T-B", "T-C"]): rpc("tab.rename", dict(tab_id=tab["tab_id"], label=name))
def order(): return [t["label"] for t in rpc("tab.list", dict(workspace_id=ws))["tabs"]]
print("server before:", order(), flush=True)
os.makedirs(temp + "/x")
Path(temp + "/x/devices.json").write_text(json.dumps([dict(id="e2e", displayName="E2E", endpoint=dict(kind="local", socketPath=path))]))
subprocess.run(["defaults", "write", "io.github.cleanwk.herdrx", "SUEnableAutomaticChecks", "-bool", "false"])
log = open(out / "tab-drag-app.log", "w")
proc = subprocess.Popen([app + "/Contents/MacOS/HerdrX"], env=env, stdout=log, stderr=subprocess.STDOUT)
def drive(*a):
    r = subprocess.run([driver, str(proc.pid), *a], capture_output=True, text=True, timeout=60)
    print(r.stdout + r.stderr, flush=True); return r.returncode
try:
    time.sleep(8)
    drive("dump")
    drive("click", "DragSpace"); time.sleep(3)
    drive("dump")
    subprocess.run(["screencapture", "-x", str(out / "tab-drag-before.png")])
    drive("drag", "T-A", "T-C")
    time.sleep(3)
    drive("order")
    print("server after:", order(), flush=True)
    subprocess.run(["screencapture", "-x", str(out / "tab-drag-after.png")])
finally:
    proc.terminate(); proc.wait(10); log.close()
    print(open(out / "tab-drag-app.log").read()[-4000:])
    try: cli("server", "stop")
    except Exception as e: print("stop:", e)

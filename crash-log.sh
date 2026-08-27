#!/bin/sh
# Dump the latest FamilyHub crash from this Mac or the connected iPad.
set -eu
cd "$(dirname "$0")"

python3 - <<'PY'
import json, os, subprocess, sys
from pathlib import Path
from datetime import datetime, timedelta

def run(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError as e:
        return (e.output or "") if isinstance(e.output, str) else ""

home = Path.home()
roots = [
    home / "Library/Logs/DiagnosticReports",
    home / "Library/Logs/CrashReporter",
    home / "Library/Logs/CrashReporter/MobileDevice",
    home / "Library/Developer/Xcode/DeviceLogs",
    home / "Library/Developer/Xcode/iOS Device Logs",
]
hits = []
cutoff = datetime.now().timestamp() - 14 * 24 * 3600
for root in roots:
    if not root.exists():
        continue
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        try:
            mtime = path.stat().st_mtime
        except OSError:
            continue
        if mtime < cutoff:
            continue
        name = path.name.lower()
        if "familyhub" in name or "jetsam" in name:
            hits.append(path)
hits.sort(key=lambda p: p.stat().st_mtime, reverse=True)
if hits:
    path = hits[0]
    print(f"FILE={path}")
    text = path.read_text(errors="replace")
    print(text[:12000])
    print("-------- matches --------")
    keys = ("crashed thread", "exception type", "termination", "familyhub", "todayview", "weather", "fatal error", "precondition", "thread 0 crashed", "swift runtime", "last exception", "jetsam")
    for i, line in enumerate(text.splitlines(), 1):
        low = line.lower()
        if any(k in low for k in keys):
            print(f"{i}: {line}")
    sys.exit(0)

json_path = Path("/tmp/familyhub-devices.json")
subprocess.run(["xcrun", "devicectl", "list", "devices", "--json-output", str(json_path)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
if not json_path.exists():
    print("Could not list devices.")
    sys.exit(1)
data = json.loads(json_path.read_text())
devices = data.get("result", {}).get("devices", []) or data.get("devices", [])
picked = None
for device in devices:
    hardware = device.get("hardwareProperties") or {}
    props = device.get("deviceProperties") or {}
    conn = device.get("connectionProperties") or {}
    name = props.get("name") or device.get("name") or ""
    marketing = str(hardware.get("marketingName") or "")
    ident = device.get("identifier") or hardware.get("udid") or ""
    udid = str(hardware.get("udid") or ident)
    tunnel = str(conn.get("tunnelState") or "").lower()
    transport = str(conn.get("transportType") or "").lower()
    is_ipad = "iPad" in name or "iPad" in marketing
    if not is_ipad:
        continue
    if "Corp" in name:
        continue
    available = tunnel in ("connected", "ready") or transport in ("wired", "localnetwork", "wifi")
    if available and ident:
        picked = (ident, udid, name)
        if tunnel in ("connected", "ready"):
            break
if not picked:
    print("No connected personal iPad. Unlock it and plug it in.")
    sys.exit(1)
ident, udid, name = picked
print(f"Device: {name}")
print(f"ID: {ident}")
print(f"UDID: {udid}")
print("-------- unified log --------")
for device_id in (ident, udid):
    log = run([
        "log", "show", "--device", device_id, "--last", "10m", "--style", "compact",
        "--predicate", 'process == "FamilyHub" OR processImagePath CONTAINS "FamilyHub"',
    ])
    if log.strip():
        print("\n".join(log.splitlines()[-180:]))
        break
else:
    mac = run([
        "log", "show", "--last", "10m", "--style", "compact",
        "--predicate", 'process == "FamilyHub" OR eventMessage CONTAINS "FamilyHub"',
    ])
    print("\n".join((mac or "No unified log lines.").splitlines()[-80:]))

print("")
print("If still empty after a crash: iPad Settings → Privacy & Security → Analytics & Improvements → Analytics Data")
print("Open the newest FamilyHub-....ips, Select All, Copy, paste it here.")
PY

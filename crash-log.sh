#!/bin/sh
# Dump a FRESH FamilyHub crash. Ignores old Jetsam files.
set -eu
cd "$(dirname "$0")"

python3 - <<'PY'
import json, os, subprocess, sys
from pathlib import Path
from datetime import datetime

def run(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return ""

home = Path.home()
roots = [
    home / "Library/Logs/DiagnosticReports",
    home / "Library/Logs/CrashReporter",
    home / "Library/Logs/CrashReporter/MobileDevice",
    home / "Library/Developer/Xcode/DeviceLogs",
    home / "Library/Developer/Xcode/iOS Device Logs",
]
cutoff = datetime.now().timestamp() - 2 * 24 * 3600
hits = []
for root in roots:
    if not root.exists():
        continue
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        name = path.name.lower()
        if "familyhub" not in name:
            continue
        try:
            if path.stat().st_mtime < cutoff:
                continue
        except OSError:
            continue
        hits.append(path)
hits.sort(key=lambda p: p.stat().st_mtime, reverse=True)
if hits:
    path = hits[0]
    print(f"FILE={path}")
    print(path.read_text(errors="replace")[:16000])
    sys.exit(0)

print("No FamilyHub .ips from the last 48 hours.")
json_path = Path("/tmp/familyhub-devices.json")
subprocess.run(
    ["xcrun", "devicectl", "list", "devices", "--json-output", str(json_path)],
    check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
)
if not json_path.exists():
    print("Could not list devices.")
    sys.exit(1)
data = json.loads(json_path.read_text())
devices = data.get("result", {}).get("devices", []) or []
picked = None
for device in devices:
    hardware = device.get("hardwareProperties") or {}
    props = device.get("deviceProperties") or {}
    conn = device.get("connectionProperties") or {}
    name = props.get("name") or ""
    ident = device.get("identifier") or ""
    udid = str(hardware.get("udid") or ident)
    tunnel = str(conn.get("tunnelState") or "").lower()
    transport = str(conn.get("transportType") or "").lower()
    if "iPad" not in name and "iPad" not in str(hardware.get("marketingName") or ""):
        continue
    if "Corp" in name:
        continue
    if tunnel in ("connected", "ready") or transport in ("wired", "localnetwork", "wifi"):
        picked = (ident, udid, name)
        if tunnel in ("connected", "ready"):
            break
if not picked:
    print("Unlock the iPad and plug it in, then run this again.")
    sys.exit(1)
ident, udid, name = picked
print(f"Device: {name}")
print(f"UDID: {udid}")
print("-------- log show --------")
shown = False
for device_id in (udid, ident):
    log = run([
        "log", "show", "--device", device_id, "--last", "10m", "--style", "compact",
        "--predicate", 'process == "FamilyHub"',
    ])
    if log.strip():
        print("\n".join(log.splitlines()[-200:]))
        shown = True
        break
if not shown:
    print("No live process log. After the next crash run:")
    print(f'  log show --device {udid} --last 8m --style compact --predicate \'process == "FamilyHub"\' | tail -120')
    print("")
    print("Or iPad: Settings → Privacy & Security → Analytics & Improvements → Analytics Data")
    print("Open the newest FamilyHub-....ips, Select All, Copy, paste here.")
PY

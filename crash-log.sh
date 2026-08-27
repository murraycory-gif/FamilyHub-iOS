#!/bin/sh
# Dump the latest FamilyHub crash from this Mac or the connected iPad.
set -eu
cd "$(dirname "$0")"

python3 - <<'PY'
import json, os, subprocess, sys
from pathlib import Path

def run(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
        return e.output or ""

home = Path.home()
roots = [
    home / "Library/Logs/DiagnosticReports",
    home / "Library/Logs/CrashReporter",
    home / "Library/Logs/CrashReporter/MobileDevice",
    home / "Library/Developer/Xcode/DeviceLogs",
    home / "Library/Developer/Xcode/iOS Device Logs",
]
hits = []
for root in roots:
    if not root.exists():
        continue
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        name = path.name.lower()
        if "familyhub" in name or (name.endswith((".ips", ".crash")) and "family" in name):
            hits.append(path)
hits.sort(key=lambda p: p.stat().st_mtime, reverse=True)
if hits:
    path = hits[0]
    print(f"FILE={path}")
    text = path.read_text(errors="replace")
    print(text[:8000])
    print("-------- matches --------")
    keys = ("crashed thread", "exception type", "termination", "familyhub", "todayview", "weather", "fatal error", "precondition", "thread 0 crashed", "swift runtime", "last exception")
    for i, line in enumerate(text.splitlines(), 1):
        low = line.lower()
        if any(k in low for k in keys):
            print(f"{i}: {line}")
    sys.exit(0)

print("No FamilyHub .ips on the Mac. Pulling live logs from the iPad...")
raw = run(["xcrun", "devicectl", "list", "devices", "--json-output", "-"])
try:
    data = json.loads(raw)
except Exception:
    print(raw)
    sys.exit(1)
devices = data.get("result", {}).get("devices", []) or data.get("devices", [])
picked = None
for device in devices:
    hardware = device.get("hardwareProperties") or {}
    props = device.get("deviceProperties") or {}
    conn = device.get("connectionProperties") or {}
    name = props.get("name") or device.get("name") or ""
    marketing = str(hardware.get("marketingName") or "")
    ident = device.get("identifier") or hardware.get("udid") or ""
    tunnel = str(conn.get("tunnelState") or "").lower()
    transport = str(conn.get("transportType") or "").lower()
    is_ipad = "iPad" in name or "iPad" in marketing
    available = tunnel in ("connected", "ready") or transport in ("wired", "localnetwork", "wifi")
    if is_ipad and available and ident:
        picked = (ident, name)
        break
if not picked:
    print("No connected iPad.")
    sys.exit(1)
udid, name = picked
print(f"Device: {name} {udid}")
print("-------- log show (last 5 min) --------")
log = run([
    "log", "show", "--device", udid, "--last", "5m", "--style", "compact",
    "--predicate", 'process == "FamilyHub" OR eventMessage CONTAINS "FamilyHub" OR eventMessage CONTAINS "fatal" OR eventMessage CONTAINS "crash"',
])
print("\n".join(log.splitlines()[-160:]))
print("")
print("If that is empty, on the iPad: Settings → Privacy & Security → Analytics & Improvements → Analytics Data")
print("Open the newest FamilyHub-....ips, Select All, Copy, paste it here.")
PY

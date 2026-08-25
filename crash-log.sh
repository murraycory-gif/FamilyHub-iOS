#!/bin/sh
# Print the latest FamilyHub crash so we can see the exact line.
set -eu
cd "$(dirname "$0")"

echo "Looking for FamilyHub crash reports..."
FILE=$(ls -t "$HOME/Library/Logs/DiagnosticReports"/FamilyHub*.ips "$HOME/Library/Logs/DiagnosticReports"/FamilyHub*.crash 2>/dev/null | head -1 || true)
if [ -z "${FILE:-}" ]; then
  FILE=$(ls -t "$HOME/Library/Logs/CrashReporter"/FamilyHub* 2>/dev/null | head -1 || true)
fi
if [ -z "${FILE:-}" ]; then
  echo "No Mac-side crash file yet. Pulling from the iPad..."
  python3 - <<'PY'
import json, subprocess, sys
raw = subprocess.check_output(["xcrun", "devicectl", "list", "devices", "--json-output", "-"], text=True)
data = json.loads(raw)
devs = []
for d in data.get("result", {}).get("devices", data.get("devices", [])):
    conn = str(d.get("connectionProperties", {}).get("transportType") or d.get("connectionType") or "")
    state = str(d.get("connectionProperties", {}).get("tunnelState") or "")
    name = str(d.get("deviceProperties", {}).get("name") or d.get("name") or "")
    udid = d.get("hardwareProperties", {}).get("udid") or d.get("identifier") or d.get("udid")
    if udid and ("wired" in conn.lower() or "connected" in state.lower() or True):
        if "iPad" in name or "iPhone" in name or True:
            devs.append((str(udid), name))
if not devs:
    sys.exit("No device found. Unlock the iPad and plug it in.")
udid, name = devs[0]
print(f"Device: {name} {udid}")
PY
  echo ""
  echo "Also try Xcode → Window → Devices and Simulators → your iPad → View Device Logs."
  echo "Or paste this after a crash:"
  echo "  log show --predicate 'process == \"FamilyHub\"' --last 2m --style compact | tail -80"
  exit 1
fi

echo "FILE=$FILE"
echo "-------- head --------"
python3 - <<PY
from pathlib import Path
p = Path("$FILE")
text = p.read_text(errors="replace")
print(text[:4000])
print("-------- crash thread --------")
keys = ("Crashed Thread", "Exception Type", "Termination Reason", "FamilyHub", "TodayView", "Weather", "Swift runtime", "fatal error", "precondition", "Thread 0")
for i, line in enumerate(text.splitlines()):
    if any(k.lower() in line.lower() for k in keys):
        print(f"{i+1}: {line}")
PY

#!/bin/sh
# Pull a FRESH FamilyHub crash from the connected iPad.
set -eu
cd "$(dirname "$0")"

python3 - <<'PY'
import json, os, shutil, subprocess, sys, time
from pathlib import Path
from datetime import datetime

UDID = "00008103-000960E61E30801E"
IDENT = "676FA816-88AE-59D9-A89D-5C17BFC2DA96"
NAME = "Corys Ipad Pro 12in"
CUTOFF = time.time() - 6 * 3600  # last 6 hours only

def run(cmd):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
        return e.output or ""
    except Exception as e:
        return str(e)

def recent_files(roots, names_must=None):
    hits = []
    for root in roots:
        root = Path(root).expanduser()
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            try:
                if path.stat().st_mtime < CUTOFF:
                    continue
            except OSError:
                continue
            name = path.name.lower()
            if names_must and not any(n in name for n in names_must):
                continue
            hits.append(path)
    hits.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return hits

home = Path.home()
roots = [
    home / "Library/Logs/DiagnosticReports",
    home / "Library/Logs/CrashReporter",
    home / "Library/Logs/CrashReporter/MobileDevice",
    home / "Library/Developer/Xcode/DeviceLogs",
    home / "Library/Developer/Xcode/iOS Device Logs",
]

print("== recent FamilyHub .ips (6h) ==")
hub_ips = recent_files(roots, ["familyhub"])
if hub_ips:
    path = hub_ips[0]
    print(f"FILE={path}")
    print(path.read_text(errors="replace")[:18000])
    sys.exit(0)
print("none")

print("== recent Jetsam mentioning FamilyHub (6h) ==")
for path in recent_files(roots, ["jetsam"]):
    text = path.read_text(errors="replace")
    if "FamilyHub" in text or "familyhub" in text.lower():
        print(f"FILE={path}")
        print(text[:12000])
        sys.exit(0)
print("none")

print("== collecting iPad log archive ==")
archive = Path("/tmp/hub-ipad.logarchive")
if archive.exists():
    shutil.rmtree(archive, ignore_errors=True)
    if archive.exists():
        archive.unlink(missing_ok=True)
collect = run([
    "log", "collect",
    "--device-udid", UDID,
    "--last", "15m",
    "--output", str(archive),
])
print(collect[-2000:])
if archive.exists():
    shown = run([
        "log", "show", str(archive),
        "--last", "15m",
        "--style", "compact",
        "--predicate", 'process CONTAINS "FamilyHub" OR eventMessage CONTAINS "FamilyHub"',
    ])
    print("-------- archive --------")
    print("\n".join(shown.splitlines()[-220:]) or shown[:4000])
    sys.exit(0)

print("log collect failed. Try Console.app:")
print("  1. Open Console (Spotlight: Console)")
print("  2. Select 'Corys Ipad Pro 12in' in the left sidebar")
print("  3. Crash Reports, copy the newest FamilyHub row")
print("Or Xcode → Window → Devices and Simulators → Corys Ipad Pro 12in → Open Recent Logs")
print("")
print("Also on the iPad: Settings → Privacy & Security → Analytics & Improvements → Analytics Data")
print("Open FamilyHub-....ips, Select All, Copy, paste here.")
PY

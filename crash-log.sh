#!/bin/sh
# Pull a FRESH FamilyHub crash from the connected iPad.
set -eu
cd "$(dirname "$0")"

IDENT="676FA816-88AE-59D9-A89D-5C17BFC2DA96"
UDID="00008103-000960E61E30801E"
OUT="/tmp/hub-crashes"
ARCHIVE="/tmp/hub-ipad.logarchive"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "== copy crashLogs from iPad (no sudo) =="
xcrun devicectl device copy from --device "$IDENT" --domain-type crashLogs --source / --destination "$OUT" 2>&1 | tail -20 || true
xcrun devicectl device copy from --device "$IDENT" --domain-type systemCrashLogs --source / --destination "$OUT" 2>&1 | tail -20 || true

python3 - <<'PY'
import os, time
from pathlib import Path
root = Path("/tmp/hub-crashes")
cutoff = time.time() - 24 * 3600
hits = []
if root.exists():
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        name = path.name.lower()
        if "familyhub" not in name and "jetsam" not in name:
            continue
        try:
            if path.stat().st_mtime < cutoff:
                continue
        except OSError:
            continue
        hits.append(path)
hits.sort(key=lambda p: p.stat().st_mtime, reverse=True)
if not hits:
    print("no copied crash files")
else:
    for path in hits[:3]:
        text = path.read_text(errors="replace")
        if "familyhub" in path.name.lower() or "FamilyHub" in text:
            print(f"FILE={path}")
            print(text[:16000])
            raise SystemExit(0)
    print("copied files, none named FamilyHub")
PY

echo ""
echo "No crash file copied. Collecting with sudo (type your Mac password)..."
rm -rf "$ARCHIVE"
if sudo log collect --device-udid "$UDID" --last 20m --output "$ARCHIVE"; then
  echo "-------- FamilyHub lines --------"
  log show "$ARCHIVE" --last 20m --style compact --predicate 'process CONTAINS "FamilyHub" OR eventMessage CONTAINS "FamilyHub"' | tail -180
else
  echo "sudo collect failed."
  echo "Xcode → Window → Devices and Simulators → Corys Ipad Pro 12in → Open Recent Logs"
fi

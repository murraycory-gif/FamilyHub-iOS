#!/bin/sh
# Pull, archive HUB, open Organizer for TestFlight upload.
set -eu
set -o pipefail
cd "$(dirname "$0")"

PROJECT="FamilyHub.xcodeproj"
SCHEME="FamilyHub"
ARCHIVE="$HOME/Library/Developer/Xcode/Archives/FamilyHub-$(date +%Y%m%d-%H%M).xcarchive"
LOG="${TMPDIR:-/tmp}/familyhub-archive.log"

echo "Pulling latest…"
git pull --rebase --autostash origin main

echo "Opening Xcode…"
open -a Xcode "$PROJECT"

echo "Archiving for App Store / TestFlight…"
mkdir -p "$(dirname "$ARCHIVE")"
if ! xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive 2>&1 | tee "$LOG"
then
  echo ""
  echo "---- archive errors ----"
  grep -E "error:" "$LOG" | tail -40 || true
  exit 1
fi

echo "Archive ready:"
echo "  $ARCHIVE"
echo "Opening Organizer — select the HUB archive → Distribute App → App Store Connect → Upload → TestFlight."
open -a Xcode "$ARCHIVE"

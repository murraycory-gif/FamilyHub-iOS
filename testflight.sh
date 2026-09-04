#!/bin/sh
# Pull, archive, and upload HUB Circle to TestFlight.
set -eu
set -o pipefail
cd "$(dirname "$0")"

PROJECT="FamilyHub.xcodeproj"
SCHEME="FamilyHub"
ARCHIVE="$HOME/Library/Developer/Xcode/Archives/FamilyHub-$(date +%Y%m%d-%H%M).xcarchive"
EXPORT_DIR="${TMPDIR:-/tmp}/FamilyHubExport"
LOG="${TMPDIR:-/tmp}/familyhub-archive.log"
EXPORT_LOG="${TMPDIR:-/tmp}/familyhub-export.log"
OPTIONS="$(pwd)/ExportOptions.plist"

echo "Pulling latest…"
git pull --rebase --autostash origin main

echo "Archiving HUB Circle for TestFlight…"
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

echo "Uploading to App Store Connect / TestFlight…"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
if ! xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$OPTIONS" \
  -allowProvisioningUpdates \
  2>&1 | tee "$EXPORT_LOG"
then
  echo ""
  echo "---- upload errors ----"
  grep -E "error:|Error" "$EXPORT_LOG" | tail -40 || true
  echo "If upload failed, open Organizer and Distribute the archive at:"
  echo "  $ARCHIVE"
  open -a Xcode "$ARCHIVE"
  exit 1
fi

echo ""
echo "Uploaded. In App Store Connect → HUB Circle → TestFlight"
echo "wait until build 15 is Ready to Test, then add testers."
echo "Build stamp:"
grep 'static let string' FamilyHub/BuildStamp.swift || true

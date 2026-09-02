#!/bin/bash
# Open Study Grove after stripping Gatekeeper quarantine.
# Double-click this file. Do not open StudyGrove.app directly from USB.
set +e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR" || exit 1

echo "Preparing Study Grove…"

if [ ! -d "$DIR/StudyGrove.app" ]; then
  echo
  echo "StudyGrove.app is missing."
  echo "Copy the whole StudyGrove folder to the Desktop, then open this file from there."
  read -r -p "Press Return to close…"
  exit 1
fi

# Quarantine is inherited from zip/USB/Downloads. Clear the whole folder.
xattr -cr "$DIR" >/dev/null 2>&1
xattr -d com.apple.quarantine "$DIR" >/dev/null 2>&1
xattr -cr "$DIR/StudyGrove.app" >/dev/null 2>&1
xattr -d com.apple.quarantine "$DIR/StudyGrove.app" >/dev/null 2>&1
find "$DIR" -exec xattr -c {} \; >/dev/null 2>&1

chmod +x "$DIR/Open Study Grove.command" >/dev/null 2>&1
chmod +x "$DIR/StudyGrove.app/Contents/MacOS/StudyGrove" >/dev/null 2>&1

# Re-sign only with USB entitlements that have no Xcode $(...) variables.
# A leftover $(AppIdentifierPrefix) keychain group can make the app
# quit unexpectedly. If entitlements look unsafe, keep the zip signature.
if command -v codesign >/dev/null 2>&1; then
  ENT=""
  if [ -f "$DIR/Usb.entitlements" ]; then
    ENT="$DIR/Usb.entitlements"
  elif [ -f "$DIR/Release.entitlements" ]; then
    ENT="$DIR/Release.entitlements"
  fi
  if [ -n "$ENT" ] && ! grep -q '\$(' "$ENT"; then
    codesign --force --deep --sign - --entitlements "$ENT" "$DIR/StudyGrove.app" >/dev/null 2>&1
  fi
fi

echo "Opening Study Grove…"
open "$DIR/StudyGrove.app"
exit 0

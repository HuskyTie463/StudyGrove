#!/bin/bash
# Open Study Grove after stripping Gatekeeper quarantine.
# Double-click this file. Do not open StudyGrove.app directly from USB.
set +e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR" || exit 1

echo "Preparing Study Grove…"

# Quarantine is inherited from zip/USB/Downloads. Clear the whole folder.
xattr -cr "$DIR" >/dev/null 2>&1
xattr -d com.apple.quarantine "$DIR" >/dev/null 2>&1
xattr -cr "$DIR/StudyGrove.app" >/dev/null 2>&1
xattr -d com.apple.quarantine "$DIR/StudyGrove.app" >/dev/null 2>&1
find "$DIR" -exec xattr -c {} \; >/dev/null 2>&1

chmod +x "$DIR/Open Study Grove.command" >/dev/null 2>&1
chmod +x "$DIR/StudyGrove.app/Contents/MacOS/StudyGrove" >/dev/null 2>&1

if command -v codesign >/dev/null 2>&1; then
  ENT="$DIR/Release.entitlements"
  if [ -f "$ENT" ]; then
    codesign --force --deep --sign - --entitlements "$ENT" "$DIR/StudyGrove.app" >/dev/null 2>&1
  else
    codesign --force --deep --sign - "$DIR/StudyGrove.app" >/dev/null 2>&1
  fi
fi

echo "Opening Study Grove…"
open "$DIR/StudyGrove.app"
exit 0

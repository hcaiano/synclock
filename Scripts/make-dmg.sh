#!/usr/bin/env bash
# Package dist/Synclock.app into a drag-to-install DMG.
#
# Usage: Scripts/make-dmg.sh [outdir]   (default: dist)
# Env:   VERSION   (default 0.1.0)
#
# Run Scripts/build-app.sh first. For a release, sign + notarize the .app
# BEFORE this, then notarize + staple the resulting DMG (see RELEASING.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-dist}"
VERSION="${VERSION:-0.1.0}"
APP="$ROOT/$OUT/Synclock.app"
DMG="$ROOT/$OUT/Synclock-$VERSION.dmg"

[ -d "$APP" ] || { echo "missing $APP — run Scripts/build-app.sh first" >&2; exit 1; }

TMP_STAGE_ROOT="$(mktemp -d)"
trap 'trash "$TMP_STAGE_ROOT"' EXIT
STAGE="$TMP_STAGE_ROOT/Synclock"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag-to-install affordance

if [[ -e "$DMG" ]]; then
  trash "$DMG"
fi
hdiutil create -volname "Synclock $VERSION" \
  -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

DEVID="${DEVELOPER_ID_IDENTITY:-$(security find-identity -p codesigning -v 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')}"
if [[ -n "$DEVID" ]]; then
  echo "› signing DMG with Developer ID"
  codesign --force --timestamp --sign "$DEVID" "$DMG"
fi

echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"
if [[ -n "$DEVID" ]]; then
  echo "  Next: Scripts/notarize.sh \"$DMG\""
fi

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

STAGE="$(mktemp -d)/Synclock"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"   # drag-to-install affordance

rm -f "$DMG"
hdiutil create -volname "Synclock $VERSION" \
  -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"

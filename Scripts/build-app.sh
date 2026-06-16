#!/usr/bin/env bash
# Build Synclock.app from the SPM release executable.
#
# Usage: Scripts/build-app.sh [outdir]   (default: dist)
# Env:
#   VERSION   marketing version          (default 0.1.0)
#   IDENTITY  codesign identity          (default ad-hoc "-")
#   UNIVERSAL build arm64+x86_64 app     (default 0)
#   SPARKLE_FEED_URL       appcast URL (default https://synclock.caiano.com/appcast.xml)
#   SPARKLE_PUBLIC_ED_KEY  Sparkle EdDSA public key; omit for local/dev builds
#
# Ad-hoc signing is fine for local runs. For release set IDENTITY to a
# "Developer ID Application: …" identity, then notarize + staple (Scripts/
# notarize.sh, added once Henrique's Apple Developer account is active).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-dist}"
VERSION="${VERSION:-0.1.0}"
IDENTITY="${IDENTITY:--}"
UNIVERSAL="${UNIVERSAL:-0}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://synclock.caiano.com/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
APP="$ROOT/$OUT/Synclock.app"
SPARKLE_PLIST_KEYS=""
SPARKLE_SEARCH_ROOT="$ROOT/.build"

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  SPARKLE_PLIST_KEYS="  <key>SUFeedURL</key><string>$SPARKLE_FEED_URL</string>
  <key>SUPublicEDKey</key><string>$SPARKLE_PUBLIC_ED_KEY</string>"
fi

echo "› building release executable…"
if [[ "$UNIVERSAL" == "1" ]]; then
  ARM64_BUILD="$ROOT/.build/synclock-arm64"
  X86_BUILD="$ROOT/.build/synclock-x86_64"
  UNIVERSAL_BUILD="$ROOT/.build/synclock-universal"
  mkdir -p "$UNIVERSAL_BUILD/release"
  ( cd "$ROOT" && swift build -c release --triple arm64-apple-macosx13.0 --scratch-path "$ARM64_BUILD" )
  ( cd "$ROOT" && swift build -c release --triple x86_64-apple-macosx13.0 --scratch-path "$X86_BUILD" )
  lipo -create \
    "$ARM64_BUILD/arm64-apple-macosx/release/synclock" \
    "$X86_BUILD/x86_64-apple-macosx/release/synclock" \
    -output "$UNIVERSAL_BUILD/release/synclock"
  SPARKLE_SEARCH_ROOT="$ARM64_BUILD"
else
  ( cd "$ROOT" && swift build -c release )
fi

echo "› assembling $APP"
if [[ -e "$APP" ]]; then
  trash "$APP"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$APP/Contents/Frameworks"
if [[ "$UNIVERSAL" == "1" ]]; then
  cp "$ROOT/.build/synclock-universal/release/synclock" "$APP/Contents/MacOS/synclock"
else
  cp "$ROOT/.build/release/synclock" "$APP/Contents/MacOS/synclock"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Synclock</string>
  <key>CFBundleDisplayName</key><string>Synclock</string>
  <key>CFBundleIdentifier</key><string>com.caiano.synclock</string>
  <key>CFBundleExecutable</key><string>synclock</string>
  <key>CFBundleIconFile</key><string>Synclock</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026 Henrique Caiano. GPLv2-or-later.</string>
$SPARKLE_PLIST_KEYS
</dict></plist>
PLIST

echo "› generating Synclock.icns from the locked branding icon"
TMP_ICONSET_ROOT="$(mktemp -d)"
trap 'trash "$TMP_ICONSET_ROOT"' EXIT
ICONSET="$TMP_ICONSET_ROOT/Synclock.iconset"
mkdir -p "$ICONSET"
EX="$ROOT/branding/app-icon/exports"
cp "$EX/synclock-icon-16.png"   "$ICONSET/icon_16x16.png"
cp "$EX/synclock-icon-32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$EX/synclock-icon-32.png"   "$ICONSET/icon_32x32.png"
cp "$EX/synclock-icon-64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$EX/synclock-icon-128.png"  "$ICONSET/icon_128x128.png"
cp "$EX/synclock-icon-256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$EX/synclock-icon-256.png"  "$ICONSET/icon_256x256.png"
cp "$EX/synclock-icon-512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$EX/synclock-icon-512.png"  "$ICONSET/icon_512x512.png"
cp "$EX/synclock-icon-1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Synclock.icns"

echo "› bundling menubar template glyphs"
for state in idle playing; do
  cp "$ROOT/branding/menubar/synclock-menubar-$state-18.png" "$APP/Contents/Resources/menubar-$state.png"
  cp "$ROOT/branding/menubar/synclock-menubar-$state-36.png" "$APP/Contents/Resources/menubar-$state@2x.png"
done

echo "› bundling Sparkle.framework"
SPARKLE_FRAMEWORK="$(find "$SPARKLE_SEARCH_ROOT" -path '*/release/Sparkle.framework' -type d | head -1)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "missing Sparkle.framework in .build release artifacts" >&2
  exit 1
fi
cp -R "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/synclock" 2>/dev/null || true

echo "› signing ($IDENTITY)"
FW="$APP/Contents/Frameworks/Sparkle.framework"
FWV="$FW/Versions/Current"
# Sparkle bundles nested code (XPC services, Autoupdate, Updater.app) that Apple
# notarization requires to be signed individually, inside-out. Real Developer ID
# releases also need a secure timestamp (--timestamp); ad-hoc local builds can't.
sign_code() {
  local target="$1"
  if [[ "$IDENTITY" == "-" ]]; then
    codesign --force --options runtime --sign "$IDENTITY" "$target"
  else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$target"
  fi
}

for nested in \
  "$FWV/XPCServices/Downloader.xpc" \
  "$FWV/XPCServices/Installer.xpc" \
  "$FWV/Autoupdate" \
  "$FWV/Updater.app"; do
  [[ -e "$nested" ]] && sign_code "$nested"
done
sign_code "$FW"
sign_code "$APP"

echo "✓ built $APP (v$VERSION)"
codesign -dv "$APP" 2>&1 | sed 's/^/  /' || true

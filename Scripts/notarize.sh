#!/usr/bin/env bash
# Notarize and staple a Developer ID-signed Synclock artifact (.app or .dmg).
#
# One-time credential setup:
#   xcrun notarytool store-credentials "synclock-notary" \
#     --apple-id <apple-id> --team-id <TEAMID> --password <app-specific-password>
#
# Usage:
#   Scripts/notarize.sh <path-to-.app-or-.dmg> [keychain-profile]
set -euo pipefail

TARGET="${1:?usage: notarize.sh <app-or-dmg> [keychain-profile]}"
PROFILE="${2:-${NOTARY_PROFILE:-synclock-notary}}"
[ -e "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }

CODESIGN_INFO="$(codesign -dvvv "$TARGET" 2>&1 || true)"
if ! printf '%s\n' "$CODESIGN_INFO" | grep -q 'Authority=Developer ID Application'; then
  echo "error: $TARGET is not signed by a Developer ID Application identity; Apple will not notarize it." >&2
  echo "       Rebuild with IDENTITY=\"Developer ID Application: ...\" or DEVELOPER_ID_IDENTITY set." >&2
  exit 1
fi

SUBMIT="$TARGET"
CLEANUP_ZIP=""
case "$TARGET" in
  *.app)
    SUBMIT="$(dirname "$TARGET")/$(basename "$TARGET" .app)-notarize.zip"
    /usr/bin/ditto -c -k --keepParent "$TARGET" "$SUBMIT"
    CLEANUP_ZIP="$SUBMIT"
    ;;
esac

cleanup() {
  if [[ -n "$CLEANUP_ZIP" && -e "$CLEANUP_ZIP" ]]; then
    trash "$CLEANUP_ZIP"
  fi
}
trap cleanup EXIT

echo "› submitting to Apple's notary service"
if ! xcrun notarytool submit "$SUBMIT" --keychain-profile "$PROFILE" --wait --timeout 30m; then
  echo "error: notarization failed. Inspect details with:" >&2
  echo "       xcrun notarytool history --keychain-profile \"$PROFILE\"" >&2
  echo "       xcrun notarytool log <submission-id> --keychain-profile \"$PROFILE\"" >&2
  exit 1
fi

echo "› stapling notarization ticket"
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"

case "$TARGET" in
  *.app)
    if command -v syspolicy_check >/dev/null 2>&1; then
      syspolicy_check distribution "$TARGET"
    else
      spctl -a -vvv -t exec "$TARGET"
    fi
    ;;
  *.dmg)
    spctl -a -vvv -t open --context context:primary-signature "$TARGET"
    ;;
esac

echo "✓ $TARGET is notarized + stapled"

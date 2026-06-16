#!/usr/bin/env bash
# Validate local release prerequisites before signing, notarizing, and publishing.
#
# Usage:
#   VERSION=0.1.0 \
#   IDENTITY="Developer ID Application: Henrique Caiano (TEAMID)" \
#   SPARKLE_PUBLIC_ED_KEY="..." \
#     Scripts/release-preflight.sh
#
# Set ALLOW_DIRTY=1 to skip the clean-worktree gate for local diagnostics only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
IDENTITY="${IDENTITY:-${DEVELOPER_ID_IDENTITY:-}}"
NOTARY_PROFILE="${NOTARY_PROFILE:-synclock-notary}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

failures=0

ok() {
  printf 'OK  %s\n' "$1"
}

warn() {
  printf 'WARN %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  failures=$((failures + 1))
}

have() {
  command -v "$1" >/dev/null 2>&1
}

check_command() {
  if have "$1"; then
    ok "$1 available"
  else
    fail "$1 missing"
  fi
}

check_command swift
check_command xcrun
check_command codesign
check_command hdiutil
check_command ditto
check_command security
check_command trash
check_command lipo

if xcrun -f iconutil >/dev/null 2>&1; then
  ok "iconutil available through xcrun"
else
  fail "iconutil unavailable through xcrun"
fi

DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEVELOPER_DIR" == *"/CommandLineTools" ]]; then
  warn "active developer directory is CommandLineTools ($DEVELOPER_DIR); release signing may still work, but full Xcode is recommended"
elif [[ -n "$DEVELOPER_DIR" ]]; then
  ok "active developer directory: $DEVELOPER_DIR"
else
  fail "xcode-select has no active developer directory"
fi

if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
fi

if [[ -n "$IDENTITY" ]] && security find-identity -p codesigning -v 2>/dev/null | grep -Fq "$IDENTITY"; then
  ok "Developer ID identity found: $IDENTITY"
else
  fail "Developer ID Application identity not found in the login keychain"
  printf '  Create/install it in Xcode Settings > Accounts > Manage Certificates, then export IDENTITY=\"Developer ID Application: ...\".\n' >&2
fi

if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  ok "notarytool profile works: $NOTARY_PROFILE"
else
  fail "notarytool profile missing or invalid: $NOTARY_PROFILE"
  printf '  Store it with: xcrun notarytool store-credentials %q --apple-id <email> --team-id <TEAMID>\n' "$NOTARY_PROFILE" >&2
fi

SPARKLE_BIN="$ROOT/.build/artifacts/sparkle/Sparkle/bin"
if [[ -x "$SPARKLE_BIN/generate_keys" && -x "$SPARKLE_BIN/generate_appcast" ]]; then
  ok "Sparkle release tools available"
else
  fail "Sparkle release tools missing; run swift build once so SwiftPM fetches Sparkle artifacts"
fi

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  ok "SPARKLE_PUBLIC_ED_KEY is set"
else
  fail "SPARKLE_PUBLIC_ED_KEY is not set"
  printf '  Generate or print it with: .build/artifacts/sparkle/Sparkle/bin/generate_keys\n' >&2
fi

if xmllint --noout "$ROOT/site/appcast.xml" >/dev/null 2>&1; then
  ok "site/appcast.xml is well-formed XML"
else
  fail "site/appcast.xml is not well-formed XML"
fi

if [[ "${ALLOW_DIRTY:-0}" == "1" ]]; then
  warn "skipping clean-worktree check because ALLOW_DIRTY=1"
else
  if git -C "$ROOT" diff --quiet &&
     git -C "$ROOT" diff --cached --quiet &&
     [[ -z "$(git -C "$ROOT" ls-files --others --exclude-standard)" ]]; then
    ok "git worktree is clean"
  else
    fail "git worktree is dirty; commit or stash changes before cutting a release"
  fi
fi

printf '\nRelease preflight: version %s\n' "$VERSION"
if (( failures > 0 )); then
  printf 'Release preflight failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

ok "release prerequisites satisfied"

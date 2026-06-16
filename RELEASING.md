# Releasing Synclock

The build is ready to ship; the only gate is an **Apple Developer ID** for
signing + notarization. Once the account is active, a release is the steps below.

## Prerequisites (one time)
- Apple Developer Program membership.
- A **Developer ID Application** certificate in your login keychain.
- An app-specific password (or `notarytool` keychain profile) for notarization:
  ```sh
  xcrun notarytool store-credentials synclock-notary \
    --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
  ```
- A **Sparkle EdDSA key** for signed updates:
  ```sh
  # from the Sparkle release tools
  ./generate_keys                 # prints the public key -> Info.plist SUPublicEDKey
  ```

## Cut a release
```sh
# 1. Build a Developer-ID-signed .app (version via env)
VERSION=0.1.0 \
IDENTITY="Developer ID Application: Henrique Caiano (TEAMID)" \
SPARKLE_PUBLIC_ED_KEY="public-key-from-generate_keys" \
  ./Scripts/build-app.sh dist

# 2. Notarize + staple
Scripts/notarize.sh dist/Synclock.app synclock-notary

# 3. Package, sign, notarize, and staple the DMG
VERSION=0.1.0 ./Scripts/make-dmg.sh dist
Scripts/notarize.sh dist/Synclock-0.1.0.dmg synclock-notary

# 4. Sign the update with Sparkle's EdDSA key and update appcast.xml
#    hosted at https://synclock.caiano.com/appcast.xml (SUFeedURL in Info.plist).

# 5. Create the GitHub Release, attach the notarized DMG.
```

## Wiring still pending (do these when the account is ready)
- Sparkle is already linked in `SynclockApp`; `Scripts/build-app.sh` writes
  `SUFeedURL` + `SUPublicEDKey` only when `SPARKLE_PUBLIC_ED_KEY` is supplied.
- Point `synclock.caiano.com` DNS at the static `site/` and host `appcast.xml`.

## License note
Synclock is GPLv2-or-later (it links Ableton Link). Publish corresponding source
with each release (the public repo satisfies this). The **Synclock name and brand
assets** are reserved and not covered by the GPL.

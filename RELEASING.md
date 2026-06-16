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
VERSION=0.1.0 IDENTITY="Developer ID Application: Henrique Caiano (TEAMID)" \
  ./Scripts/build-app.sh dist

# 2. Notarize + staple
xcrun notarytool submit dist/Synclock.app --keychain-profile synclock-notary --wait
xcrun stapler staple dist/Synclock.app

# 3. Package a DMG (already implemented), then notarize + staple it too.
VERSION=0.1.0 ./Scripts/make-dmg.sh dist
xcrun notarytool submit dist/Synclock-0.1.0.dmg --keychain-profile synclock-notary --wait
xcrun stapler staple dist/Synclock-0.1.0.dmg

# 4. Sign the update with Sparkle's EdDSA key and update appcast.xml
#    hosted at https://synclock.caiano.com/appcast.xml (SUFeedURL in Info.plist).

# 5. Create the GitHub Release, attach the notarized DMG.
```

## Wiring still pending (do these when the account is ready)
- Add Sparkle as an SPM dependency and an `SPUStandardUpdaterController` in
  `SynclockApp` (the Info.plist `SUFeedURL` / `SUPublicEDKey` keys are stubbed in
  `Scripts/build-app.sh`).
- Add `Scripts/make-dmg.sh` and `Scripts/notarize.sh` (mirror Lineup's).
- Point `synclock.caiano.com` DNS at the static `site/` and host `appcast.xml`.

## License note
Synclock is GPLv2-or-later (it links Ableton Link). Publish corresponding source
with each release (the public repo satisfies this). The **Synclock name and brand
assets** are reserved and not covered by the GPL.

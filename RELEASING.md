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
  # from the Sparkle release tools fetched by SwiftPM
  .build/artifacts/sparkle/Sparkle/bin/generate_keys
  # prints the public key -> pass it as SPARKLE_PUBLIC_ED_KEY
  # private key stays in the login Keychain; do not commit it.
  ```

## Cut a release
```sh
# 0. Verify the local release machine is ready.
VERSION=0.1.0 \
IDENTITY="Developer ID Application: Henrique Caiano (TEAMID)" \
SPARKLE_PUBLIC_ED_KEY="public-key-from-generate_keys" \
  ./Scripts/release-preflight.sh

# 1. Build an Apple-Silicon Developer-ID-signed .app.
#    Future universal builds can add UNIVERSAL=1 here.
VERSION=0.1.0 \
IDENTITY="Developer ID Application: Henrique Caiano (TEAMID)" \
SPARKLE_PUBLIC_ED_KEY="public-key-from-generate_keys" \
  ./Scripts/build-app.sh dist

# 2. Notarize + staple
Scripts/notarize.sh dist/Synclock.app synclock-notary

# 3. Package, sign, notarize, and staple the DMG
VERSION=0.1.0 ./Scripts/make-dmg.sh dist
Scripts/notarize.sh dist/Synclock-0.1.0.dmg synclock-notary

# 4. Generate the signed Sparkle appcast.
#    Sparkle's generate_appcast signs the DMG and writes appcast.xml.
mkdir -p dist/updates
cp dist/Synclock-0.1.0.dmg dist/updates/
.build/artifacts/sparkle/Sparkle/bin/generate_appcast \
  --download-url-prefix "https://github.com/hcaiano/synclock/releases/download/v0.1.0/" \
  --link "https://synclock.caiano.com/" \
  dist/updates/

# 5. Copy dist/updates/appcast.xml to site/appcast.xml and deploy site/.
#    The DMG must be uploaded at the URL emitted in the appcast item.

# 6. Create the GitHub Release, attach the notarized DMG.
```

## Wiring still pending (do these when the account is ready)
- Sparkle is already linked in `SynclockApp`; `Scripts/build-app.sh` writes
  `SUFeedURL` + `SUPublicEDKey` only when `SPARKLE_PUBLIC_ED_KEY` is supplied.
- `synclock.caiano.com` is already live from the static `site/` Worker.
- `site/appcast.xml` is a valid empty placeholder. Replace it with the signed
  `generate_appcast` output for the first notarized release.

## License note
Synclock is GPLv2-or-later (it links Ableton Link). Publish corresponding source
with each release (the public repo satisfies this). The **Synclock name and brand
assets** are reserved and not covered by the GPL.

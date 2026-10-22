# macOS packaging and release checks

A drag-to-Applications DMG is appropriate for this standalone menu-bar app. A privileged PKG installer would add complexity without installing anything the app needs. ZIP is also produced as an alternative.

## Version authority

The native app's release version is `CFBundleShortVersionString` and its monotonically increasing build number is `CFBundleVersion`, both in `native/Info.plist`. Update these before preparing a release. Root `VERSION`, `BUILD_NUMBER`, and `make version-*` belong only to the retained upstream Rust/Xcode app; they do not version TrackpadSwipe.

## Developer ID release

On a Mac with Xcode Command Line Tools and a valid **Developer ID Application** certificate/private key in its configured keychains:

```sh
export DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)'
export NOTARY_PROFILE='your-existing-notarytool-profile'
native/package.sh release
```

Store notarization credentials using Apple's `notarytool store-credentials` on the build machine; never put passwords or API keys in this repository. An Apple Development certificate is not a Developer ID distribution certificate. See [Apple’s Developer ID guide](https://developer.apple.com/developer-id/) for creating the distribution identity. The script deliberately fails if the required identity/profile is not supplied, or if signing, notarization, stapling, or Gatekeeper assessment fails.

The script builds a universal app for macOS 15+, signs with hardened runtime and a timestamp, submits a ZIP for notarization, staples the app ticket, and assesses the app with Gatekeeper. It then creates/signs/notarizes/staples the DMG and generates the final ZIP and SHA-256 checksums. No app is installed or running process stopped by packaging.

## Local preview package

```sh
native/package.sh --preview
```

This creates ad hoc signed **UNNOTARIZED-preview** DMG and ZIP files for testing, with an explicit warning inside the DMG. It does not use or change the local development signing keychain. These are not a substitute for a notarized release.

## Validate before publishing

Run `native/check.sh`. Check the app bundle's architecture slices, signature, dictionary checksum and all bundled third-party notices. Mount the DMG read-only and verify the app, Applications link, and installation guide. For a notarized release, validate both stapled tickets and test a downloaded, quarantined copy on a different Mac/account. Exercise three-finger click, opening at screen edges, live predictions, click-off, corrections, permission loss, Esc, and sleep/wake using the [manual test list](../native/TEST_RESULTS.md).

Generated artifacts live under ignored `native/build/dist/`. GitHub is not a binary distribution channel: do not upload packages to Releases, Actions artifacts, or Pages. Packaging does not publish anything. Publish only verified artifacts and their checksum file, and clearly state known limitations and supported/tested hardware. Keep the app identity stable across distribution updates; never bundle signing keys or notarization credentials.

## Repeatable artifact verification

Packaging automatically runs the verifier before reporting success. To recheck an existing pair against this source checkout:

```sh
python3 native/tools/verify-package.py native/build/dist/TrackpadSwipe-0.2.0-UNNOTARIZED-preview.dmg --preview
# For the Developer ID release, use the non-preview DMG and --release.
```

Verification mounts read-only without opening Finder, checks both DMG and ZIP app bundles, exact version/build, architecture slices, resource checksums, licenses, and the installation guide, then unmounts. Release mode additionally requires Developer ID, hardened runtime, stapled tickets, and app Gatekeeper assessment. It never installs or launches the packaged app. Matching preview labels and checksums are mandatory.

GitHub Actions runs native checks and universal compilation on macOS 15 for pushes and pull requests. It has read-only repository permissions, no signing secrets, and does not publish artifacts.

## Publication checklist

1. Resolve every Important/Critical review finding. Update native version/build and release notes.
2. Confirm the live candidate on the intended trackpad/editor, including conditional spaces, correction, activation click consumption, Esc, screen edges, sleep/wake, and permission loss. Record actual results.
3. Run native/check.sh and require a green Native macOS checks workflow for the release commit.
4. Build with Developer ID and notarize using native/package.sh release; the artifact verifier must pass.
5. Test a downloaded, quarantined copy on a clean account or another Mac.
6. Review [the prepared release notes](releases/v0.2.0.md), select a non-GitHub download host with the owner, and publish only the verified DMG, ZIP, and checksum manifest as an experimental preview. Publication is a separate authorized action.

If the only visible certificate is Apple Development, create/import **Developer ID Application** with its private key using [Apple's certificate instructions](https://developer.apple.com/help/account/certificates/create-developer-id-certificates). Resolve that certificate and an existing notarytool profile before release packaging. Neither a preview nor local development signing substitutes for this step.

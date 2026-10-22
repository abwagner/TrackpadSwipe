#!/bin/sh
# Default: Developer ID signed and notarized universal distribution.
# --preview produces an explicitly unnotarized local testing package.
set -eu
cd "$(dirname "$0")"
task_mode=${1:-release}
case "$task_mode" in
  release)
    : "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to a valid Developer ID Application identity}"
    : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to an existing notarytool keychain profile}"
    case "$DEVELOPER_ID_APPLICATION" in 'Developer ID Application: '*) ;; *) printf 'A Developer ID Application identity is required.\n' >&2;exit 2;; esac ;;
  --preview) ;;
  *) printf 'Usage: native/package.sh [release|--preview]\n' >&2;exit 2 ;;
esac
mkdir -p build/dist
task_work=$(mktemp -d "$PWD/build/package.XXXXXX")
trap 'rm -rf "$task_work"' EXIT HUP INT TERM
task_app="$task_work/image/TrackpadSwipe.app"
./assemble.sh "$task_app" universal
task_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
task_suffix=''
if [ "$task_mode" = --preview ]; then
  task_suffix='-UNNOTARIZED-preview'
  codesign --force --sign - --identifier com.andz.TrackpadType "$task_app"
else
  codesign --force --sign "$DEVELOPER_ID_APPLICATION" --options runtime --timestamp "$task_app"
fi
codesign --verify --strict "$task_app"
"$task_app/Contents/MacOS/TrackpadType" --self-test
task_name="TrackpadSwipe-$task_version$task_suffix"
if [ "$task_mode" = release ]; then
  ditto -c -k --sequesterRsrc --keepParent "$task_app" "$task_work/notarize.zip"
  xcrun notarytool submit "$task_work/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$task_app"
  xcrun stapler validate "$task_app"
  spctl --assess --type execute --verbose "$task_app"
fi
ln -s /Applications "$task_work/image/Applications"
cp ../docs/INSTALL_PACKAGE.txt "$task_work/image/INSTALL.txt"
if [ "$task_mode" = --preview ]; then
  printf 'UNNOTARIZED preview for testing. Not an Apple-verified public release.\nSee INSTALL.txt for first-launch steps.\n' > "$task_work/image/UNNOTARIZED-PREVIEW.txt"
fi
hdiutil create -quiet -volname TrackpadSwipe -srcfolder "$task_work/image" -format UDZO "$task_work/$task_name.dmg"
if [ "$task_mode" = release ]; then
  codesign --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$task_work/$task_name.dmg"
  xcrun notarytool submit "$task_work/$task_name.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$task_work/$task_name.dmg"
  xcrun stapler validate "$task_work/$task_name.dmg"
fi
ditto -c -k --sequesterRsrc --keepParent "$task_app" "$task_work/$task_name.zip"
cp "$task_work/$task_name.dmg" "$task_work/$task_name.zip" build/dist/
(cd build/dist && shasum -a 256 "$task_name.dmg" "$task_name.zip" > "$task_name.sha256")
if [ "$task_mode" = --preview ]; then
  python3 tools/verify-package.py "$PWD/build/dist/$task_name.dmg" --preview
else
  python3 tools/verify-package.py "$PWD/build/dist/$task_name.dmg" --release
fi
printf 'Created build/dist/%s.{dmg,zip,sha256}\n' "$task_name"

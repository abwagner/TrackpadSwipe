#!/bin/sh
# Compile a standalone app bundle. No signing, installation, or credentials.
set -eu
cd "$(dirname "$0")"
task_destination=${1:?Usage: native/assemble.sh /absolute/path/App.app [host|universal]}
case "$task_destination" in /*.app) ;; *) printf 'Use an absolute .app output path.\n' >&2;exit 2;; esac
test ! -e "$task_destination" || { printf 'Output already exists: %s\n' "$task_destination" >&2;exit 1; }
case "${2:-host}" in
  host) task_archs=$(uname -m) ;;
  universal) task_archs='arm64 x86_64' ;;
  *) printf 'Architecture must be host or universal.\n' >&2;exit 2 ;;
esac
python3 tools/check-dictionary.py
task_work=$(mktemp -d "${TMPDIR:-/tmp}/trackpadswipe-assemble.XXXXXX")
trap 'rm -rf "$task_work"' EXIT HUP INT TERM
task_bundle="$task_work/TrackpadSwipe.app"
mkdir -p "$task_bundle/Contents/MacOS" "$task_bundle/Contents/Resources"
for task_arch in $task_archs; do
  clang -arch "$task_arch" -mmacosx-version-min=15.0 -Wall -Wextra -Werror -O2 -c TrackpadBridge.c -o "$task_work/$task_arch.o"
  swiftc -swift-version 5 -O -target "$task_arch-apple-macos15.0" -import-objc-header TrackpadBridge.h \
    Core.swift main.swift "$task_work/$task_arch.o" -framework AppKit -framework ApplicationServices \
    -framework Carbon -o "$task_work/$task_arch"
done
if [ "${2:-host}" = universal ]; then
  lipo -create "$task_work/arm64" "$task_work/x86_64" -output "$task_bundle/Contents/MacOS/TrackpadType"
else
  cp "$task_work/$task_arch" "$task_bundle/Contents/MacOS/TrackpadType"
fi
cp Info.plist "$task_bundle/Contents/Info.plist"
cp ../word_freq.txt "$task_bundle/Contents/Resources/word_freq.txt"
cp ../LICENSE "$task_bundle/Contents/Resources/SwipeType-LICENSE.txt"
cp ../licenses/OpenMultitouchSupport-MIT.txt "$task_bundle/Contents/Resources/OpenMultitouchSupport-LICENSE.txt"
cp ../licenses/wordfreq-NOTICE.md "$task_bundle/Contents/Resources/wordfreq-NOTICE.md"
cp ../THIRD_PARTY_NOTICES.md ../docs/dictionary.json "$task_bundle/Contents/Resources/"
mkdir -p "$(dirname "$task_destination")"
mv "$task_bundle" "$task_destination"
printf 'Assembled %s (%s)\n' "$task_destination" "${2:-host}"

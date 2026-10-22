#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
# This directory contains generated staging output only.
rm -rf build/TrackpadType.app
./assemble.sh "$PWD/build/TrackpadType.app" host
./sign.sh build/TrackpadType.app
build/TrackpadType.app/Contents/MacOS/TrackpadType --self-test
task_install="$HOME/Applications/TrackpadType.app"
mkdir -p "$HOME/Applications"
if [ -e "$task_install" ]; then
  task_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$task_install/Contents/Info.plist")
  if [ "$task_bundle" != com.andz.TrackpadType ]; then
    printf 'Refusing to replace an unrelated app at %s\n' "$task_install" >&2
    exit 1
  fi
fi
# Stop the local prototype before replacing its on-disk code signature.
killall TrackpadType 2>/dev/null || true
if [ -e build/TrackpadType.previous ]; then rm -rf build/TrackpadType.previous; fi
if [ -e "$task_install" ]; then mv "$task_install" build/TrackpadType.previous; fi
if ! mv build/TrackpadType.app "$task_install"; then
  if [ -e build/TrackpadType.previous ]; then mv build/TrackpadType.previous "$task_install"; fi
  exit 1
fi
printf 'Installed %s\n' "$task_install"

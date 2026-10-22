#!/bin/sh
# Build and check without installing an app or accessing signing credentials.
set -eu
cd "$(dirname "$0")"
python3 tools/check-dictionary.py
task_scratch=$(mktemp -d "${TMPDIR:-/tmp}/trackpadswipe-check.XXXXXX")
trap 'rm -rf "$task_scratch"' EXIT HUP INT TERM
clang -Wall -Wextra -Werror -O2 test-bridge.c -framework ApplicationServices -framework CoreFoundation -o "$task_scratch/bridge-check"
"$task_scratch/bridge-check"
clang -Wall -Wextra -Werror -O2 -c TrackpadBridge.c -o "$task_scratch/TrackpadBridge.o"
swiftc -swift-version 5 -O -import-objc-header TrackpadBridge.h Core.swift main.swift \
  "$task_scratch/TrackpadBridge.o" -framework AppKit -framework ApplicationServices \
  -framework Carbon -o "$task_scratch/TrackpadSwipe"
"$task_scratch/TrackpadSwipe" --self-test
plutil -lint Info.plist
for task_script in ./*.sh ./trackpadswipe ./trackpadtype; do sh -n "$task_script"; done

#!/bin/sh
# Reuse production drawing declarations without running the app or posting input.
set -eu
cd "$(dirname "$0")/.."
task_output=${1:-"$PWD/../docs/assets/hello-demo.gif"}
task_work=$(mktemp -d "${TMPDIR:-/tmp}/trackpadswipe-media.XXXXXX")
trap 'rm -rf "$task_work"' EXIT HUP INT TERM
python3 - "$task_work/main.swift" <<'PY'
from pathlib import Path
import sys
source=Path('main.swift').read_text().split('if CommandLine.arguments.contains("--self-test")')[0]
Path(sys.argv[1]).write_text(source+Path('tools/render-hello-demo.swift').read_text())
PY
clang -Wall -Wextra -Werror -O2 -c TrackpadBridge.c -o "$task_work/bridge.o"
swiftc -swift-version 5 -O -import-objc-header TrackpadBridge.h Core.swift "$task_work/main.swift" "$task_work/bridge.o" \
  -framework AppKit -framework ApplicationServices -framework Carbon -o "$task_work/render"
"$task_work/render" "$task_output" "$PWD/../word_freq.txt"

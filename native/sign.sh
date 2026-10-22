#!/bin/sh
set -eu
task_state="$HOME/Library/Application Support/TrackpadTypeSigning"
task_keychain="$task_state/TrackpadType.keychain-db"
if [ ! -f "$task_state/identity.sha1" ]; then
  printf 'Run native/setup-signing.sh once before building. No ad hoc fallback is used.\n' >&2
  exit 1
fi
task_identity=$(cat "$task_state/identity.sha1")
case "$task_identity" in ''|*[!0-9A-Fa-f]*) printf 'Invalid signing identity fingerprint.\n' >&2;exit 1;; esac
task_password=$(cat "$task_state/keychain-password")
security unlock-keychain -p "$task_password" "$task_keychain"
python3 "$(dirname "$0")/register-signing-keychain.py" "$task_keychain"
task_requirement="=designated => identifier \"com.andz.TrackpadType\" and certificate leaf = H\"$task_identity\""
codesign --force --sign "$task_identity" --keychain "$task_keychain" \
  --identifier com.andz.TrackpadType --requirements "$task_requirement" "$1"
codesign --verify --strict "$1"
